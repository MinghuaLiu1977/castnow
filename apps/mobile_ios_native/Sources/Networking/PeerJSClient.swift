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
}

/// PeerJS-compatible signaling client.
/// Protocol: HTTP GET to register ID → WebSocket for signaling.
final class PeerJSClient: NSObject, URLSessionWebSocketDelegate {
    private var webSocket: URLSessionWebSocketTask?
    private let host = "0.peerjs.com"
    private let port = 443
    private let path = "/"        // PeerJS cloud default path
    private let key = "peerjs"
    private let token: String

    private(set) var peerId: String?
    var onEvent: ((PeerEvent) -> Void)?

    static let defaultIceServers: [RTCIceServer] = [
        RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"]),
        RTCIceServer(urlStrings: ["stun:stun.miwifi.com:3478"]),
        RTCIceServer(urlStrings: ["stun:stun.cdn.aliyun.com:3478"]),
        RTCIceServer(urlStrings: ["stun:stun.cloudflare.com:3478"])
    ]

    override init() {
        // Generate random token (matches PeerJS client behavior)
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        self.token = bytes.map { String(format: "%02x", $0) }.joined()
        super.init()
    }

    // MARK: - Connect

    func connect(id: String) {
        peerId = id
        let basePath = "https://\(host):\(port)\(path)"

        // Step 1: HTTP GET to register ID and verify availability
        var components = URLComponents(string: basePath)!
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

            // Step 2: Open WebSocket with same query params
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
    }

    func disconnect() {
        print("🔌 [PeerJS] disconnect")
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
    }

    // MARK: - Send

    func sendOffer(to dst: String, sdp: String) {
        print("📤 [PeerJS] OFFER → \(dst)")
        send(json: [
            "type": "OFFER",
            "payload": [
                "src": peerId ?? "",
                "dst": dst,
                "sdp": ["type": "OFFER", "sdp": sdp],
                "connectionId": "cnv_\(dst)_\(peerId ?? "")",
                "metadata": ["device": "CastNow", "os": "iOS"]
            ]
        ])
    }

    func sendAnswer(to dst: String, sdp: String) {
        print("📤 [PeerJS] ANSWER → \(dst)")
        send(json: [
            "type": "ANSWER",
            "payload": [
                "src": peerId ?? "",
                "dst": dst,
                "sdp": ["type": "ANSWER", "sdp": sdp],
                "connectionId": "cnv_\(peerId ?? "")_\(dst)"
            ]
        ])
    }

    func sendCandidate(to dst: String, candidate: String, sdpMLineIndex: Int32, sdpMid: String?) {
        var payload: [String: Any] = [
            "src": peerId ?? "",
            "dst": dst,
            "candidate": [
                "candidate": candidate,
                "sdpMLineIndex": Int(sdpMLineIndex),
                "sdpMid": sdpMid ?? ""
            ],
            "connectionId": "cnv_\(dst)_\(peerId ?? "")"
        ]
        if let sdpMid = sdpMid { payload["sdpMid"] = sdpMid }
        send(json: ["type": "CANDIDATE", "payload": payload])
    }

    func sendLeave(to dst: String) {
        print("📤 [PeerJS] LEAVE → \(dst)")
        send(json: ["type": "LEAVE", "payload": ["src": peerId ?? "", "dst": dst]])
    }

    private func send(json: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: json) else { return }
        webSocket?.send(.data(data)) { error in
            if let error = error {
                print("❌ [PeerJS] WS send error: \(error.localizedDescription)")
            }
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
        case .data(let data):
            rawText = String(data: data, encoding: .utf8)
        case .string(let text):
            rawText = text
        @unknown default:
            break
        }

        guard let text = rawText else { return }
        print("📥 [PeerJS] recv: \(text.prefix(200))")

        // PeerJS server sends OPEN confirmation or signaling messages as JSON
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            print("⚠️ [PeerJS] non-JSON or missing type: \(text.prefix(100))")
            return
        }

        let payload = json["payload"] as? [String: Any] ?? [:]

        switch type {
        case "OPEN":
            let id = payload["id"] as? String ?? peerId ?? ""
            peerId = id
            print("✅ [PeerJS] OPEN confirmed, id=\(id)")
            DispatchQueue.main.async { self.onEvent?(.opened(id)) }

        case "OFFER":
            // PeerJS wraps SDP inside payload.sdp as {type, sdp}
            let sdpStr = extractSdp(payload)
            let src = payload["src"] as? String ?? ""
            print("📥 [PeerJS] OFFER from \(src)")
            if let sdp = sdpStr {
                var offer = PeerOffer(sdp: sdp)
                offer.sourcePeerId = src
                DispatchQueue.main.async { self.onEvent?(.offer(offer)) }
            }

        case "ANSWER":
            let sdpStr = extractSdp(payload)
            let src = payload["src"] as? String ?? ""
            print("📥 [PeerJS] ANSWER from \(src)")
            if let sdp = sdpStr {
                DispatchQueue.main.async { self.onEvent?(.answer(PeerOffer(sdp: sdp))) }
            }

        case "CANDIDATE":
            // PeerJS wraps candidate inside payload.candidate as {candidate, sdpMLineIndex, sdpMid}
            let (cand, mline, mid) = extractCandidate(payload)
            if let cand = cand {
                print("📥 [PeerJS] CANDIDATE from \(payload["src"] ?? "?")")
                DispatchQueue.main.async {
                    self.onEvent?(.candidate(RTCIceCandidate(sdp: cand, sdpMLineIndex: mline, sdpMid: mid)))
                }
            }

        case "LEAVE", "EXPIRE":
            print("📥 [PeerJS] \(type)")
            DispatchQueue.main.async { self.onEvent?(.close) }

        case "ERROR":
            let msg = payload["msg"] as? String ?? "Unknown PeerJS error"
            print("❌ [PeerJS] SERVER ERROR: \(msg)")
            DispatchQueue.main.async { self.onEvent?(.error(msg)) }

        case "HEARTBEAT":
            // Respond to heartbeat to keep connection alive
            send(json: ["type": "HEARTBEAT"])

        default:
            print("⚠️ [PeerJS] unhandled type: \(type)")
        }
    }

    // MARK: - SDP extraction (PeerJS wraps SDP differently)

    private func extractSdp(_ payload: [String: Any]) -> String? {
        // PeerJS v1: payload.sdp is { "type": "OFFER", "sdp": "v=0..." }
        if let sdpObj = payload["sdp"] as? [String: Any],
           let sdp = sdpObj["sdp"] as? String {
            return sdp
        }
        // Fallback: payload.sdp is a plain string
        if let sdp = payload["sdp"] as? String {
            return sdp
        }
        return nil
    }

    private func extractCandidate(_ payload: [String: Any]) -> (String?, Int32, String?) {
        // PeerJS v1: payload.candidate is { "candidate": "...", "sdpMLineIndex": 0, "sdpMid": "0" }
        if let candObj = payload["candidate"] as? [String: Any] {
            let cand = candObj["candidate"] as? String
            let mline = Int32(candObj["sdpMLineIndex"] as? Int ?? 0)
            let mid = candObj["sdpMid"] as? String
            return (cand, mline, mid)
        }
        // Fallback: flat payload
        let cand = payload["candidate"] as? String
        let mline = Int32(payload["sdpMLineIndex"] as? Int ?? 0)
        let mid = payload["sdpMid"] as? String
        return (cand, mline, mid)
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