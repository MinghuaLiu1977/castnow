import Foundation
import WebRTC

enum PeerEvent {
    case opened(String)          // peer connected, id
    case offer(PeerOffer)
    case answer(PeerOffer)
    case candidate(RTCIceCandidate)
    case close
    case error(String)
}

struct PeerOffer: Codable {
    let sdp: String
    var sourcePeerId: String = ""

    static func payload(_ sdp: String) -> [String: Any] {
        return ["sdp": sdp]
    }
}

/// Minimal PeerJS-compatible signaling client over WebSocket.
/// Interoperates with the web receiver at castnow.padap.cn (which uses PeerJS).
final class PeerJSClient: NSObject, URLSessionWebSocketDelegate {
    private var webSocket: URLSessionWebSocketTask?
    private let host = "0.peerjs.com"
    private let port = 443
    private let path = "/peerjs"
    private let key = "peerjs"

    private(set) var peerId: String?
    private var pendingOffer: PeerOffer?

    var onEvent: ((PeerEvent) -> Void)?
    var iceServers: [RTCIceServer] { PeerJSClient.defaultIceServers }

    static let defaultIceServers: [RTCIceServer] = [
        RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"]),
        RTCIceServer(urlStrings: ["stun:stun.miwifi.com:3478"]),
        RTCIceServer(urlStrings: ["stun:stun.cdn.aliyun.com:3478"]),
        RTCIceServer(urlStrings: ["stun:stun.cloudflare.com:3478"])
    ]

    func connect(id: String) {
        let scheme = "wss"
        let urlStr = "\(scheme)://\(host):\(port)\(path)?key=\(key)&id=\(id)"
        guard let url = URL(string: urlStr) else { return }
        let request = URLRequest(url: url)
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        let task = session.webSocketTask(with: request)
        self.webSocket = task
        task.resume()
        receive()
    }

    func disconnect() {
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
    }

    func sendOffer(to dst: String, sdp: String) {
        send(json: [
            "type": "OFFER",
            "payload": [
                "src": peerId ?? "",
                "dst": dst,
                "sdp": sdp,
                "metadata": [
                    "device": "CastNow",
                    "os": "iOS"
                ]
            ]
        ])
    }

    func sendAnswer(to dst: String, sdp: String) {
        send(json: [
            "type": "ANSWER",
            "payload": ["src": peerId ?? "", "dst": dst, "sdp": sdp]
        ])
    }

    func sendCandidate(to dst: String, candidate: String, sdpMLineIndex: Int32, sdpMid: String?) {
        var payload: [String: Any] = [
            "src": peerId ?? "",
            "dst": dst,
            "candidate": candidate,
            "sdpMLineIndex": Int(sdpMLineIndex)
        ]
        if let sdpMid = sdpMid { payload["sdpMid"] = sdpMid }
        send(json: ["type": "CANDIDATE", "payload": payload])
    }

    func sendLeave(to dst: String) {
        send(json: ["type": "LEAVE", "payload": ["src": peerId ?? "", "dst": dst]])
    }

    private func send(json: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: json) else { return }
        webSocket?.send(.data(data)) { _ in }
    }

    private func receive() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                self.handle(message: message)
                self.receive()
            case .failure(_):
                self.onEvent?(.close)
            }
        }
    }

    private func handle(message: URLSessionWebSocketTask.Message) {
        var json: [String: Any]?
        switch message {
        case .data(let data):
            json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        case .string(let text):
            json = (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? [String: Any]
        @unknown default:
            break
        }
        guard let json = json,
              let type = json["type"] as? String,
              let payload = json["payload"] as? [String: Any] else { return }

        switch type {
        case "OPEN":
            self.peerId = payload["id"] as? String ?? self.peerId
            self.onEvent?(.opened(self.peerId ?? ""))
        case "OFFER":
            if let sdp = payload["sdp"] as? String {
                var offer = PeerOffer(sdp: sdp)
                offer.sourcePeerId = payload["src"] as? String ?? ""
                self.onEvent?(.offer(offer))
            }
        case "ANSWER":
            if let sdp = payload["sdp"] as? String {
                self.onEvent?(.answer(PeerOffer(sdp: sdp)))
            }
        case "CANDIDATE":
            guard let candidate = payload["candidate"] as? String else { return }
            let mline = Int32(payload["sdpMLineIndex"] as? Int ?? 0)
            let mid = payload["sdpMid"] as? String
            self.onEvent?(.candidate(RTCIceCandidate(sdp: candidate, sdpMLineIndex: mline, sdpMid: mid)))
        case "LEAVE":
            self.onEvent?(.close)
        default:
            break
        }
    }

    func urlSession(_ session: URLSession,
                    webSocketTask: URLSessionWebSocketTask,
                    didOpenWithProtocol protocol: String?) {
    }

    func urlSession(_ session: URLSession,
                    webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
                    reason: Data?) {
        self.onEvent?(.close)
    }
}