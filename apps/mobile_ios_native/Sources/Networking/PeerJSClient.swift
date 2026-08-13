import Foundation
import os.log
import Starscream
import WebRTC

enum PeerEvent {
    case opened(String)
    case offer(PeerOffer)
    case answer(PeerOffer)
    case candidate(RTCIceCandidate)
    case close
    case error(String)
}

struct PeerOffer: Codable {
    let sdp: String
    var sourcePeerId: String = ""
    var connectionId: String = ""
}

let peerLog = OSLog(subsystem: "com.eastlakestudio.castnow", category: "PeerJS")

func plog(_ msg: String) {
    os_log("%{public}@", log: peerLog, type: .info, msg)
    print(msg)
    let logFile = NSTemporaryDirectory() + "castnow_peer.log"
    let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
    let line = "[\(timestamp)] \(msg)\n"
    if let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: logFile)) {
        handle.seekToEndOfFile()
        handle.write(Data(line.utf8))
        handle.closeFile()
    } else {
        try? line.write(toFile: logFile, atomically: true, encoding: .utf8)
    }
}

/// PeerJS signaling client using Starscream (HTTP/1.1 WebSocket).
final class PeerJSClient: NSObject, WebSocketDelegate {

    private var socket: Starscream.WebSocket?
    private let host = "0.peerjs.com"
    private let wsPath = "/peerjs"  // PeerJS JS client with path '/' connects to '/peerjs'
    private let key = "peerjs"
    private let token: String

    private(set) var peerId: String?
    private var mediaConnectionId: String = ""
    private var heartbeatTimer: Timer?
    private var wsConnected = false

    var onEvent: ((PeerEvent) -> Void)?

    static let defaultIceServers: [RTCIceServer] = [
        RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"]),
        RTCIceServer(urlStrings: ["stun:stun.miwifi.com:3478"]),
        RTCIceServer(urlStrings: ["stun:stun.cdn.aliyun.com:3478"]),
        RTCIceServer(urlStrings: ["stun:stun.cloudflare.com:3478"])
    ]

    override init() {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        self.token = bytes.map { String(format: "%02x", $0) }.joined()
        super.init()
    }

    // MARK: - Connect

    func resetConnectionId() {
        var cid = [UInt8](repeating: 0, count: 8)
        _ = SecRandomCopyBytes(kSecRandomDefault, cid.count, &cid)
        mediaConnectionId = "mc_" + cid.map { String(format: "%02x", $0) }.joined()
    }

    func connect(id: String) {
        peerId = id
        resetConnectionId()

        plog("╔══ [PeerJS] connect() (Starscream HTTP/1.1) ══════")
        plog("║ peerId = \(id)")
        plog("║ token = \(token)")
        plog("║ mediaConnectionId = \(mediaConnectionId)")
        plog("╚══════════════════════════════════════════════════")

        var components = URLComponents(string: "wss://\(host)\(wsPath)")!
        components.queryItems = [
            URLQueryItem(name: "key", value: key),
            URLQueryItem(name: "id", value: id),
            URLQueryItem(name: "token", value: token),
            URLQueryItem(name: "version", value: "1.5.4")
        ]
        let wsUrl = components.url!
        plog("🔌 [PeerJS] WS URL: \(wsUrl.absoluteString)")

        var request = URLRequest(url: wsUrl)
        request.timeoutInterval = 10
        let ws = Starscream.WebSocket(request: request)
        ws.delegate = self
        self.socket = ws
        ws.connect()

        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self = self, !self.wsConnected else { return }
            plog("❌ [PeerJS] Timeout: no OPEN after 10s")
            self.onEvent?(.error("连接信令服务器超时"))
        }
    }

    func disconnect() {
        plog("🔌 [PeerJS] disconnect()")
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        socket?.disconnect()
        socket = nil
        wsConnected = false
    }

    private func startHeartbeat() {
        // Send first heartbeat immediately, then every 5s
        sendRaw(["type": "HEARTBEAT"])
        socket?.write(ping: Data())
        DispatchQueue.main.async { [weak self] in
            self?.heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
                guard let self = self, self.wsConnected else { return }
                self.sendRaw(["type": "HEARTBEAT"])
                self.socket?.write(ping: Data())
                plog("💓 [PeerJS] heartbeat sent")
            }
        }
    }

    // MARK: - Send

    func sendOffer(to dst: String, sdp: String) {
        plog("📤 [PeerJS] SEND OFFER → \(dst) | connId=\(mediaConnectionId)")
        // Exact PeerJS format: NO src at root (server adds it), sdp.type is lowercase
        sendRaw([
            "type": "OFFER",
            "dst": dst,
            "payload": [
                "sdp": ["type": "offer", "sdp": sdp],
                "type": "media",
                "connectionId": mediaConnectionId,
                "metadata": [:]
            ] as [String: Any]
        ])
    }

    func sendAnswer(to dst: String, sdp: String) {
        plog("📤 [PeerJS] SEND ANSWER → \(dst)")
        sendRaw([
            "type": "ANSWER",
            "dst": dst,
            "payload": [
                "sdp": ["type": "answer", "sdp": sdp],
                "type": "media",
                "connectionId": mediaConnectionId
            ] as [String: Any]
        ])
    }

    func sendCandidate(to dst: String, candidate: String, sdpMLineIndex: Int32, sdpMid: String?) {
        plog("📤 [PeerJS] SEND CANDIDATE → \(dst)")
        sendRaw([
            "type": "CANDIDATE",
            "dst": dst,
            "payload": [
                "candidate": [
                    "candidate": candidate,
                    "sdpMLineIndex": Int(sdpMLineIndex),
                    "sdpMid": sdpMid ?? ""
                ],
                "type": "media",
                "connectionId": mediaConnectionId
            ] as [String: Any]
        ])
    }

    func sendLeave(to dst: String) {
        plog("📤 [PeerJS] SEND LEAVE → \(dst)")
        sendRaw([
            "type": "LEAVE",
            "dst": dst,
            "payload": [:]
        ])
    }

    private func sendRaw(_ json: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: json),
              let str = String(data: data, encoding: .utf8) else {
            plog("❌ [PeerJS] JSON serialization failed")
            return
        }
        guard let ws = socket else {
            plog("❌ [PeerJS] socket is nil")
            return
        }
        // Log exact JSON for OFFER/ANSWER/CANDIDATE
        if let type = json["type"] as? String, type != "HEARTBEAT" {
            plog("📤 [PeerJS] SEND raw JSON: \(str.prefix(500))")
        }
        ws.write(string: str)
    }

    // MARK: - Starscream WebSocketDelegate

    func didReceive(event: WebSocketEvent, client: WebSocketClient) {
        switch event {
        case .connected(let headers):
            wsConnected = true
            plog("✅ [PeerJS] WebSocket CONNECTED! headers=\(headers.keys.sorted())")
            startHeartbeat()

        case .disconnected(let reason, let code):
            wsConnected = false
            plog("🔌 [PeerJS] WebSocket DISCONNECTED code=\(code) reason=\(reason)")
            heartbeatTimer?.invalidate()
            DispatchQueue.main.async { self.onEvent?(.close) }

        case .text(let text):
            handleMessage(text)

        case .binary(let data):
            if let text = String(data: data, encoding: .utf8) {
                handleMessage(text)
            }

        case .error(let error):
            wsConnected = false
            plog("❌ [PeerJS] WebSocket ERROR: \(error?.localizedDescription ?? "nil")")
            plog("❌ [PeerJS] Error domain: \((error as? NSError)?.domain ?? "?") code: \((error as? NSError)?.code ?? -1)")
            heartbeatTimer?.invalidate()
            DispatchQueue.main.async { self.onEvent?(.close) }

        case .viabilityChanged(let viable):
            plog("ℹ️ [PeerJS] viability=\(viable)")

        case .reconnectSuggested(let suggested):
            plog("ℹ️ [PeerJS] reconnectSuggested=\(suggested)")

        case .cancelled:
            wsConnected = false
            plog("🔌 [PeerJS] WebSocket CANCELLED")
            heartbeatTimer?.invalidate()
            DispatchQueue.main.async { self.onEvent?(.close) }

        case .peerClosed:
            wsConnected = false
            plog("🔌 [PeerJS] peerClosed")
            heartbeatTimer?.invalidate()
            DispatchQueue.main.async { self.onEvent?(.close) }

        default:
            plog("⚠️ [PeerJS] unknown or unhandled event")
        }
    }

    // MARK: - Message handling

    private func handleMessage(_ text: String) {
        var display = text
        if display.count > 500 {
            display = String(display.prefix(200)) + " ...(\(text.count) chars)... " + String(display.suffix(100))
        }
        plog("📥 [PeerJS] RECV: \(display)")

        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            plog("⚠️ [PeerJS] parse failed or no type")
            return
        }

        let payload = json["payload"] as? [String: Any] ?? [:]
        plog("📥 [PeerJS] type=\(type) keys=\(payload.keys.sorted())")

        switch type {
        case "OPEN":
            let id = (payload["id"] as? String) ?? peerId ?? ""
            peerId = id
            plog("✅ [PeerJS] OPEN! peerId=\(id)")
            DispatchQueue.main.async { self.onEvent?(.opened(id)) }

        case "OFFER":
            // src/dst are at JSON root level
            let src = (json["src"] as? String) ?? (payload["src"] as? String) ?? "?"
            let connId = payload["connectionId"] as? String ?? ""
            let ptype = payload["type"] as? String ?? "?"
            plog("📥 OFFER from=\(src) connId=\(connId) ptype=\(ptype)")
            // CRITICAL: adopt the incoming connectionId so ANSWER/CANDIDATE match
            if !connId.isEmpty { mediaConnectionId = connId }
            if let sdp = extractSdp(payload) {
                DispatchQueue.main.async {
                    self.onEvent?(.offer(PeerOffer(sdp: sdp, sourcePeerId: src, connectionId: connId)))
                }
            }

        case "ANSWER":
            let src = (json["src"] as? String) ?? (payload["src"] as? String) ?? "?"
            plog("📥 ANSWER from=\(src)")
            if let sdp = extractSdp(payload) {
                DispatchQueue.main.async { self.onEvent?(.answer(PeerOffer(sdp: sdp, sourcePeerId: src))) }
            }

        case "CANDIDATE":
            let src = (json["src"] as? String) ?? (payload["src"] as? String) ?? "?"
            let (cand, mline, mid) = extractCandidate(payload)
            plog("📥 CANDIDATE from=\(src)")
            if let cand = cand {
                DispatchQueue.main.async {
                    self.onEvent?(.candidate(RTCIceCandidate(sdp: cand, sdpMLineIndex: mline, sdpMid: mid)))
                }
            }

        case "LEAVE", "EXPIRE":
            plog("📥 \(type)")
            DispatchQueue.main.async { self.onEvent?(.close) }

        case "ERROR":
            let msg = (payload["msg"] as? String) ?? "?"
            plog("❌ SERVER ERROR: \(msg)")
            DispatchQueue.main.async { self.onEvent?(.error(msg)) }

        case "HEARTBEAT":
            sendRaw(["type": "HEARTBEAT"])

        case "ID-TAKEN":
            plog("❌ ID-TAKEN")
            DispatchQueue.main.async { self.onEvent?(.error("ID-TAKEN")) }

        case "INVALID-ID":
            plog("❌ INVALID-ID")
            DispatchQueue.main.async { self.onEvent?(.error("INVALID-ID")) }

        default:
            plog("⚠️ UNHANDLED type=\(type)")
        }
    }

    // MARK: - Extract

    private func extractSdp(_ payload: [String: Any]) -> String? {
        if let obj = payload["sdp"] as? [String: Any], let s = obj["sdp"] as? String { return s }
        return payload["sdp"] as? String
    }

    private func extractCandidate(_ payload: [String: Any]) -> (String?, Int32, String?) {
        if let obj = payload["candidate"] as? [String: Any] {
            return (obj["candidate"] as? String,
                    Int32(obj["sdpMLineIndex"] as? Int ?? 0),
                    obj["sdpMid"] as? String)
        }
        return (payload["candidate"] as? String,
                Int32(payload["sdpMLineIndex"] as? Int ?? 0),
                payload["sdpMid"] as? String)
    }
}