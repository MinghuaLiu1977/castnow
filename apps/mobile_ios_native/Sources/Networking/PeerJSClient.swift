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

/// PeerJS-compatible signaling client.
/// Matches the exact wire protocol used by peerjs npm library and peerdart.
final class PeerJSClient: NSObject, URLSessionWebSocketDelegate {
    private var webSocket: URLSessionWebSocketTask?
    private let host = "0.peerjs.com"
    private let port = 443
    private let path = "/"
    private let key = "peerjs"
    private let token: String

    private(set) var peerId: String?
    /// Connection ID shared across OFFER/ANSWER/CANDIDATE for one media session.
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
    }

    // MARK: - Connect

    func connect(id: String) {
        peerId = id
        // Generate a media connection ID (matches PeerJS format: mc_<random>)
        var cid = [UInt8](repeating: 0, count: 8)
        _ = SecRandomCopyBytes(kSecRandomDefault, cid.count, &cid)
        mediaConnectionId = "mc_" + cid.map { String(format: "%02x", $0) }.joined()

        var components = URLComponents(string: "https://\(host):\(port)\(path)")!
        components.queryItems = [
            URLQueryItem(name: "key", value: key),
            URLQueryItem(name: "id", value: id),
            URLQueryItem(name: "token", value: token)
        ]
        let httpUrl = components.url!
        print("🔗 [PeerJS] HTTP GET: \(httpUrl.absoluteString)")

        var request = URLRequest(url: httpUrl)
        request.httpMethod = "GET"

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            if let error = error {
                print("❌ [PeerJS] HTTP error: \(error.localizedDescription)")
                DispatchQueue.main.async { self.onEvent?(.error("HTTP: \(error.localizedDescription)")) }
                return
            }
            if let data = data, let body = String(data: data, encoding: .utf8) {
                print("✅ [PeerJS] HTTP response: \(body)")
            }
            self.openWebSocket()
        }.resume()
    }

    private func openWebSocket() {
        guard let peerId = peerId else { return }

        var components = URLComponents(string: "wss://\(host):\(port)\(path)")!
        components.queryItems = [
            URLQueryItem(name: "key", value: key),
            URLQueryItem(name: "id", value: peerId),
            URLQueryItem(name: "token", value: token)
        ]
        let wsUrl = components.url!
        print("🔗 [PeerJS] WS connect: \(wsUrl.absoluteString)")

        let request = URLRequest(url: wsUrl)
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let task = session.webSocketTask(with: request)
        self.webSocket = task
        task.resume()
        receive()
        startHeartbeat()
    }

    func disconnect() {
        print("🔌 [PeerJS] disconnect")
        heartbeatTimer?.invalidate()
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
    }

    private func startHeartbeat() {
        DispatchQueue.main.async { [weak self] in
            self?.heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
                self?.send(json: ["type": "HEARTBEAT"])
            }
        }
    }

    // MARK: - Send (PeerJS wire protocol)

    func sendOffer(to dst: String, sdp: String) {
        print("📤 [PeerJS] OFFER → \(dst) connId=\(mediaConnectionId)")
        send(json: [
            "type": "OFFER",
            "payload": [
                "src": peerId ?? "",
                "dst": dst,
                "serialization": "binary",
                "sdp": ["type": "OFFER", "sdp": sdp],
                "connectionId": mediaConnectionId,
                "type": "media",               // CRITICAL: PeerJS checks this
                "metadata": ["device": "CastNow", "os": "iOS"]
            ] as [String: Any]
        ])
    }

    func sendAnswer(to dst: String, sdp: String) {
        print("📤 [PeerJS] ANSWER → \(dst) connId=\(mediaConnectionId)")
        send(json: [
            "type": "ANSWER",
            "payload": [
                "src": peerId ?? "",
                "dst": dst,
                "sdp": ["type": "ANSWER", "sdp": sdp],
                "connectionId": mediaConnectionId,
                "type": "media"
            ] as [String: Any]
        ])
    }

    func sendCandidate(to dst: String, candidate: String, sdpMLineIndex: Int32, sdpMid: String?) {
        send(json: [
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
        ])
    }

    func sendLeave(to dst: String) {
        send(json: ["type": "LEAVE", "payload": ["src": peerId ?? "", "dst": dst]])
    }

    private func send(json: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: json) else { return }
        webSocket?.send(.data(data)) { error in
            if let error = error { print("❌ [PeerJS] WS send error: \(error.localizedDescription)") }
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
                print("❌ [PeerJS] WS receive error: \(error.localizedDescription)")
                DispatchQueue.main.async { self.onEvent?(.close) }
            }
        }
    }

    private func handle(message: URLSessionWebSocketTask.Message) {
        var rawText: String?
        switch message {
        case .data(let data): rawText = String(data: data, encoding: .utf8)
        case .string(let text): rawText = text
        @unknown default: break
        }
        guard let text = rawText else { return }
        print("📥 [PeerJS] recv: \(text.prefix(300))")

        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        let payload = json["payload"] as? [String: Any] ?? [:]

        switch type {
        case "OPEN":
            let id = (payload["id"] as? String) ?? peerId ?? ""
            peerId = id
            print("✅ [PeerJS] OPEN confirmed, id=\(id)")
            DispatchQueue.main.async { self.onEvent?(.opened(id)) }

        case "OFFER":
            let sdpStr = extractSdp(payload)
            let src = payload["src"] as? String ?? ""
            let connId = payload["connectionId"] as? String ?? ""
            print("📥 [PeerJS] OFFER from \(src) connId=\(connId)")
            // Adopt the connectionId from the incoming offer
            if !connId.isEmpty { mediaConnectionId = connId }
            if let sdp = sdpStr {
                var offer = PeerOffer(sdp: sdp, sourcePeerId: src, connectionId: connId)
                DispatchQueue.main.async { self.onEvent?(.offer(offer)) }
            }

        case "ANSWER":
            let sdpStr = extractSdp(payload)
            let src = payload["src"] as? String ?? ""
            print("📥 [PeerJS] ANSWER from \(src)")
            if let sdp = sdpStr {
                DispatchQueue.main.async { self.onEvent?(.answer(PeerOffer(sdp: sdp, sourcePeerId: src))) }
            }

        case "CANDIDATE":
            let (cand, mline, mid) = extractCandidate(payload)
            if let cand = cand {
                print("📥 [PeerJS] CANDIDATE")
                DispatchQueue.main.async {
                    self.onEvent?(.candidate(RTCIceCandidate(sdp: cand, sdpMLineIndex: mline, sdpMid: mid)))
                }
            }

        case "LEAVE", "EXPIRE":
            print("📥 [PeerJS] \(type)")
            DispatchQueue.main.async { self.onEvent?(.close) }

        case "ERROR":
            let msg = payload["msg"] as? String ?? "Unknown error"
            print("❌ [PeerJS] ERROR: \(msg)")
            DispatchQueue.main.async { self.onEvent?(.error(msg)) }

        case "HEARTBEAT":
            send(json: ["type": "HEARTBEAT"])

        case "ID-TAKEN":
            print("❌ [PeerJS] ID taken!")
            DispatchQueue.main.async { self.onEvent?(.error("ID taken")) }

        case "INVALID-ID":
            print("❌ [PeerJS] Invalid ID")
            DispatchQueue.main.async { self.onEvent?(.error("Invalid ID")) }

        default:
            print("⚠️ [PeerJS] unhandled type: \(type) payload: \(payload)")
        }
    }

    // MARK: - SDP / Candidate extraction

    private func extractSdp(_ payload: [String: Any]) -> String? {
        if let sdpObj = payload["sdp"] as? [String: Any],
           let sdp = sdpObj["sdp"] as? String { return sdp }
        return payload["sdp"] as? String
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
        print("🔗 [PeerJS] WebSocket connected")
    }

    func urlSession(_ session: URLSession,
                    webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
                    reason: Data?) {
        print("🔌 [PeerJS] WebSocket closed: \(closeCode)")
        DispatchQueue.main.async { self.onEvent?(.close) }
    }

    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
}