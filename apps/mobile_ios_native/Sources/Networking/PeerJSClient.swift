import Foundation
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

/// PeerJS-compatible signaling client with exhaustive logging.
final class PeerJSClient: NSObject, URLSessionWebSocketDelegate {

    // ── MUST be retained for WebSocket delegate callbacks ──
    private var urlSession: URLSession!
    private var webSocket: URLSessionWebSocketTask?

    private let host = "0.peerjs.com"
    private let port = 443
    private let path = "/"
    private let key = "peerjs"
    private let token: String

    private(set) var peerId: String?
    private var mediaConnectionId: String = ""
    private var heartbeatTimer: Timer?

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
        // Create a long-lived URLSession
        self.urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }

    // MARK: - Connect

    func connect(id: String) {
        peerId = id
        var cid = [UInt8](repeating: 0, count: 8)
        _ = SecRandomCopyBytes(kSecRandomDefault, cid.count, &cid)
        mediaConnectionId = "mc_" + cid.map { String(format: "%02x", $0) }.joined()

        print("╔══════════════════════════════════════════════════")
        print("║ [PeerJS] connect() called")
        print("║ [PeerJS] peerId = \(id)")
        print("║ [PeerJS] token = \(token)")
        print("║ [PeerJS] mediaConnectionId = \(mediaConnectionId)")
        print("╚══════════════════════════════════════════════════")

        // Step 1: HTTP GET to check ID availability
        var components = URLComponents(string: "https://\(host):\(port)\(path)")!
        components.queryItems = [
            URLQueryItem(name: "key", value: key),
            URLQueryItem(name: "id", value: id),
            URLQueryItem(name: "token", value: token)
        ]
        let httpUrl = components.url!
        print("📡 [PeerJS] HTTP GET → \(httpUrl.absoluteString)")

        var request = URLRequest(url: httpUrl)
        request.httpMethod = "GET"

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else {
                print("❌ [PeerJS] HTTP callback: self is nil!")
                return
            }

            if let error = error {
                print("❌ [PeerJS] HTTP error: \(error)")
                DispatchQueue.main.async { self.onEvent?(.error("HTTP: \(error.localizedDescription)")) }
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("📡 [PeerJS] HTTP status: \(httpResponse.statusCode)")
            }

            if let data = data {
                let body = String(data: data, encoding: .utf8) ?? "<binary>"
                print("📡 [PeerJS] HTTP response body: \(body)")
            } else {
                print("⚠️ [PeerJS] HTTP response: no body")
            }

            self.openWebSocket()
        }.resume()
    }

    private func openWebSocket() {
        guard let peerId = peerId else {
            print("❌ [PeerJS] openWebSocket: peerId is nil!")
            return
        }

        var components = URLComponents(string: "wss://\(host):\(port)\(path)")!
        components.queryItems = [
            URLQueryItem(name: "key", value: key),
            URLQueryItem(name: "id", value: peerId),
            URLQueryItem(name: "token", value: token)
        ]
        let wsUrl = components.url!
        print("🔌 [PeerJS] WebSocket connecting → \(wsUrl.absoluteString)")

        let request = URLRequest(url: wsUrl)
        let task = urlSession.webSocketTask(with: request)
        self.webSocket = task
        task.resume()
        receive()
        startHeartbeat()
    }

    func disconnect() {
        print("🔌 [PeerJS] disconnect()")
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
    }

    private func startHeartbeat() {
        DispatchQueue.main.async { [weak self] in
            self?.heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
                self?.sendRaw(["type": "HEARTBEAT"])
            }
        }
    }

    // MARK: - Send

    func sendOffer(to dst: String, sdp: String) {
        let msg: [String: Any] = [
            "type": "OFFER",
            "payload": [
                "src": peerId ?? "",
                "dst": dst,
                "serialization": "binary",
                "sdp": ["type": "OFFER", "sdp": sdp],
                "connectionId": mediaConnectionId,
                "type": "media",
                "metadata": ["device": "CastNow", "os": "iOS"]
            ] as [String: Any]
        ]
        printLog("SEND OFFER", dst: dst, msg: msg, sdpPreview: String(sdp.prefix(80)))
        sendRaw(msg)
    }

    func sendAnswer(to dst: String, sdp: String) {
        let msg: [String: Any] = [
            "type": "ANSWER",
            "payload": [
                "src": peerId ?? "",
                "dst": dst,
                "sdp": ["type": "ANSWER", "sdp": sdp],
                "connectionId": mediaConnectionId,
                "type": "media"
            ] as [String: Any]
        ]
        printLog("SEND ANSWER", dst: dst, msg: msg, sdpPreview: String(sdp.prefix(80)))
        sendRaw(msg)
    }

    func sendCandidate(to dst: String, candidate: String, sdpMLineIndex: Int32, sdpMid: String?) {
        let msg: [String: Any] = [
            "type": "CANDIDATE",
            "payload": [
                "src": peerId ?? "",
                "dst": dst,
                "candidate": [
                    "candidate": candidate,
                    "sdpMLineIndex": Int(sdpMLineIndex),
                    "sdpMid": sdpMid ?? ""
                ],
                "connectionId": mediaConnectionId,
                "type": "media"
            ] as [String: Any]
        ]
        printLog("SEND CANDIDATE", dst: dst, msg: msg, sdpPreview: candidate)
        sendRaw(msg)
    }

    func sendLeave(to dst: String) {
        let msg: [String: Any] = ["type": "LEAVE", "payload": ["src": peerId ?? "", "dst": dst]]
        printLog("SEND LEAVE", dst: dst, msg: msg, sdpPreview: nil)
        sendRaw(msg)
    }

    private func sendRaw(_ json: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: json) else {
            print("❌ [PeerJS] Failed to serialize JSON")
            return
        }
        guard let ws = webSocket else {
            print("❌ [PeerJS] WebSocket is nil, cannot send")
            return
        }
        ws.send(.data(data)) { error in
            if let error = error {
                print("❌ [PeerJS] WS send error: \(error)")
            }
        }
    }

    private func printLog(_ direction: String, dst: String?, msg: [String: Any], sdpPreview: String?) {
        print("📤 [PeerJS] \(direction) → \(dst ?? "?") | connId=\(mediaConnectionId)")
        if let pretty = try? JSONSerialization.data(withJSONObject: msg, options: [.prettyPrinted]),
           let str = String(data: pretty, encoding: .utf8) {
            // Print full JSON but limit SDP to first 80 chars for readability
            var trimmed = str
            if let sdp = sdpPreview {
                print("   sdp preview: \(sdp)...")
            }
            print("   full JSON (\(trimmed.count) bytes):")
            print(trimmed)
        }
    }

    // MARK: - Receive

    private func receive() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                self.handle(message: message)
                self.receive()
            case .failure(let error):
                print("❌ [PeerJS] WS receive error: \(error)")
                print("❌ [PeerJS] WS receive error domain: \(error) code: \((error as NSError).code)")
                DispatchQueue.main.async { self.onEvent?(.close) }
            }
        }
    }

    private func handle(message: URLSessionWebSocketTask.Message) {
        var rawText: String?
        switch message {
        case .data(let data):
            rawText = String(data: data, encoding: .utf8)
            print("📥 [PeerJS] RECV (\(data.count) bytes data)")
        case .string(let text):
            rawText = text
            print("📥 [PeerJS] RECV (\(text.count) chars string)")
        @unknown default:
            print("⚠️ [PeerJS] RECV unknown message type")
            break
        }
        guard let text = rawText else {
            print("⚠️ [PeerJS] RECV: could not decode text")
            return
        }

        // Print full message (truncate very long SDP)
        var displayText = text
        if text.count > 500 {
            displayText = String(text.prefix(200)) + "\n... (\(text.count) chars total) ...\n" + String(text.suffix(100))
        }
        print("📥 [PeerJS] RECV raw: \(displayText)")

        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("⚠️ [PeerJS] RECV: JSON parse failed")
            return
        }

        guard let type = json["type"] as? String else {
            print("⚠️ [PeerJS] RECV: no 'type' field. Keys: \(json.keys.sorted())")
            return
        }

        let payload = json["payload"] as? [String: Any] ?? [:]
        print("📥 [PeerJS] RECV type=\(type) payloadKeys=\(payload.keys.sorted())")

        switch type {
        case "OPEN":
            let id = (payload["id"] as? String) ?? peerId ?? ""
            peerId = id
            print("✅ [PeerJS] OPEN confirmed! peerId=\(id)")
            DispatchQueue.main.async { self.onEvent?(.opened(id)) }

        case "OFFER":
            let src = payload["src"] as? String ?? "?"
            let connId = payload["connectionId"] as? String ?? ""
            let payloadType = payload["type"] as? String ?? "?"
            let sdpStr = extractSdp(payload)
            print("📥 [PeerJS] OFFER from=\(src) connId=\(connId) payloadType=\(payloadType)")
            if !connId.isEmpty { mediaConnectionId = connId }
            if let sdp = sdpStr {
                let offer = PeerOffer(sdp: sdp, sourcePeerId: src, connectionId: connId)
                DispatchQueue.main.async { self.onEvent?(.offer(offer)) }
            } else {
                print("⚠️ [PeerJS] OFFER: could not extract SDP!")
            }

        case "ANSWER":
            let src = payload["src"] as? String ?? "?"
            let connId = payload["connectionId"] as? String ?? ""
            let payloadType = payload["type"] as? String ?? "?"
            let sdpStr = extractSdp(payload)
            print("📥 [PeerJS] ANSWER from=\(src) connId=\(connId) payloadType=\(payloadType)")
            if let sdp = sdpStr {
                DispatchQueue.main.async { self.onEvent?(.answer(PeerOffer(sdp: sdp, sourcePeerId: src))) }
            } else {
                print("⚠️ [PeerJS] ANSWER: could not extract SDP!")
            }

        case "CANDIDATE":
            let src = payload["src"] as? String ?? "?"
            let (cand, mline, mid) = extractCandidate(payload)
            print("📥 [PeerJS] CANDIDATE from=\(src) cand=\(cand?.prefix(50) ?? "nil") mline=\(mline) mid=\(mid ?? "nil")")
            if let cand = cand {
                DispatchQueue.main.async {
                    self.onEvent?(.candidate(RTCIceCandidate(sdp: cand, sdpMLineIndex: mline, sdpMid: mid)))
                }
            }

        case "LEAVE", "EXPIRE":
            let src = (payload["src"] as? String) ?? (payload["dst"] as? String) ?? "?"
            print("📥 [PeerJS] \(type) from/to=\(src)")
            DispatchQueue.main.async { self.onEvent?(.close) }

        case "ERROR":
            let errType = payload["type"] as? String ?? "?"
            let msg = payload["msg"] as? String ?? "Unknown error"
            print("❌ [PeerJS] SERVER ERROR type=\(errType) msg=\(msg)")
            DispatchQueue.main.async { self.onEvent?(.error("\(errType): \(msg)")) }

        case "HEARTBEAT":
            // Server heartbeat, respond to keep alive
            sendRaw(["type": "HEARTBEAT"])

        case "ID-TAKEN":
            print("❌ [PeerJS] ID-TAKEN: peerId \(peerId ?? "?") is already in use!")
            DispatchQueue.main.async { self.onEvent?(.error("ID-TAKEN")) }

        case "INVALID-ID":
            print("❌ [PeerJS] INVALID-ID: peerId \(peerId ?? "?") is invalid!")
            DispatchQueue.main.async { self.onEvent?(.error("INVALID-ID")) }

        default:
            print("⚠️ [PeerJS] UNHANDLED type=\(type)")
            print("⚠️ [PeerJS] full payload: \(payload)")
        }
    }

    // MARK: - SDP / Candidate extraction

    private func extractSdp(_ payload: [String: Any]) -> String? {
        // PeerJS v1+ wraps SDP as {"type":"OFFER","sdp":"v=0..."}
        if let sdpObj = payload["sdp"] as? [String: Any] {
            print("   extractSdp: sdp is dict, keys=\(sdpObj.keys.sorted())")
            return sdpObj["sdp"] as? String
        }
        // Some versions send SDP as plain string
        if let sdpStr = payload["sdp"] as? String {
            print("   extractSdp: sdp is string")
            return sdpStr
        }
        print("   extractSdp: sdp NOT FOUND! payload keys=\(payload.keys.sorted())")
        return nil
    }

    private func extractCandidate(_ payload: [String: Any]) -> (String?, Int32, String?) {
        if let candObj = payload["candidate"] as? [String: Any] {
            return (candObj["candidate"] as? String,
                    Int32(candObj["sdpMLineIndex"] as? Int ?? 0),
                    candObj["sdpMid"] as? String)
        }
        return (payload["candidate"] as? String,
                Int32(payload["sdpMLineIndex"] as? Int ?? 0),
                payload["sdpMid"] as? String)
    }

    // MARK: - URLSessionWebSocketDelegate

    func urlSession(_ session: URLSession,
                    webSocketTask: URLSessionWebSocketTask,
                    didOpenWithProtocol proto: String?) {
        print("✅ [PeerJS] WebSocket OPENED (protocol=\(proto ?? "none"))")
    }

    func urlSession(_ session: URLSession,
                    webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
                    reason: Data?) {
        let reasonStr = reason.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        print("🔌 [PeerJS] WebSocket CLOSED code=\(closeCode.rawValue) reason=\(reasonStr)")
        heartbeatTimer?.invalidate()
        DispatchQueue.main.async { self.onEvent?(.close) }
    }

    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        print("🔐 [PeerJS] TLS challenge from \(challenge.protectionSpace.host)")
        if let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}