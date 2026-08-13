import Foundation
import WebRTC

enum WebrtcRole {
    case broadcaster
    case receiver
}

protocol WebRTCManagerDelegate: AnyObject {
    func rtcConnectStateChanged(_ connected: Bool)
    func rtcRemoteVideoTracksReceived(_ tracks: [RTCVideoTrack])
    func rtcError(_ message: String)
}

/// Encapsulates RTCPeerConnection setup, offers/answers exchange.
final class WebRTCManager: NSObject, RTCPeerConnectionDelegate {
    weak var delegate: WebRTCManagerDelegate?

    let factory: RTCPeerConnectionFactory
    private var peerConnection: RTCPeerConnection?

    // Broadcaster side
    private var localVideoSource: RTCVideoSource?
    private var socketCapturer: SocketVideoCapturer?
    private var videoTrack: RTCVideoTrack?

    // Receiver side
    private(set) var remoteStream: RTCMediaStream?
    private var localAudioTrack: RTCAudioTrack?

    override init() {
        let encoderFactory = RTCDefaultVideoEncoderFactory()
        let decoderFactory = RTCDefaultVideoDecoderFactory()
        factory = RTCPeerConnectionFactory(
            encoderFactory: encoderFactory,
            decoderFactory: decoderFactory
        )
        super.init()
    }

    func createPeerConnection() {
        let config = RTCConfiguration()
        config.sdpSemantics = .unifiedPlan
        config.iceServers = PeerJSClient.defaultIceServers
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: ["DtlsSrtpKeyAgreement": "true"]
        )
        peerConnection = factory.peerConnection(
            with: config,
            constraints: constraints,
            delegate: self
        )
    }

    // MARK: - Broadcaster

    func startScreenCapture() -> RTCVideoSource {
        let source = factory.videoSource()
        let capturer = SocketVideoCapturer(source: source)
        capturer.start()
        localVideoSource = source
        socketCapturer = capturer
        return source
    }

    func addVideoTrack() -> RTCVideoTrack? {
        guard let source = localVideoSource else { return nil }
        return factory.videoTrack(with: source, trackId: "screen0")
    }

    func attachBroadcastTrack(_ track: RTCVideoTrack) {
        videoTrack = track
        peerConnection?.add(track, streamIds: ["screen"])
    }

    func setScreenPreviewHandler(_ handler: @escaping (UIImage) -> Void) {
        socketCapturer?.onPreviewFrame = handler
    }

    var onRemoteOffer: ((String) -> Void)?

    // MARK: - Audio Configuration
    
    func setupLocalAudio() {
        guard localAudioTrack == nil else { return }
        
        let audioConstrains = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let audioSource = factory.audioSource(with: audioConstrains)
        let audioTrack = factory.audioTrack(with: audioSource, trackId: "audio_mic")
        
        self.localAudioTrack = audioTrack
        
        if let pc = peerConnection {
            pc.add(audioTrack, streamIds: ["audio_stream"])
        }
        
        // Start muted by default unless user enables it
        audioTrack.isEnabled = false
    }
    
    func enableLocalMicrophone(_ enabled: Bool) {
        localAudioTrack?.isEnabled = enabled
    }
    
    func enableRemoteSpeaker(_ enabled: Bool) {
        remoteStream?.audioTracks.forEach { $0.isEnabled = enabled }
        
        let transceivers = peerConnection?.transceivers ?? []
        for transceiver in transceivers {
            if let audioTrack = transceiver.receiver.track as? RTCAudioTrack {
                audioTrack.isEnabled = enabled
            }
        }
    }

    // MARK: - Receiver: answer incoming offer

    func setRemoteDescription(_ sdp: String) {
        let desc = RTCSessionDescription(type: .offer, sdp: sdp)
        peerConnection?.setRemoteDescription(desc) { [weak self] error in
            if let error = error {
                self?.delegate?.rtcError("setRemoteDescription: \(error.localizedDescription)")
                return
            }
            self?.createAnswer()
        }
    }

    private func createAnswer() {
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        peerConnection?.answer(for: constraints) { [weak self] sdp, error in
            guard let self = self, let sdp = sdp else {
                self?.delegate?.rtcError("answer failed: \(error?.localizedDescription ?? "")")
                return
            }
            self.peerConnection?.setLocalDescription(sdp) { err in
                if let err = err { self.delegate?.rtcError("setLocal(desc): \(err.localizedDescription)") }
            }
            self.onRemoteOffer?(sdp.sdp)
        }
    }

    var onLocalAnswer: ((String) -> Void)?
    var onLocalOffer: ((String, String) -> Void)?  // (sdp, dstPeerId)
    var onIceCandidate: ((RTCIceCandidate, String) -> Void)?  // (candidate, dstPeerId)
    private var pendingLocalSdp: String?

    func createOffer(destPeer: String) {
        // Receiver side wants to receive; broadcaster alone doesn't initiate.
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        peerConnection?.offer(for: constraints) { [weak self] sdp, error in
            guard let self = self, let sdp = sdp else {
                self?.delegate?.rtcError("offer failed")
                return
            }
            self.peerConnection?.setLocalDescription(sdp) { err in
                if let err = err { self.delegate?.rtcError("setLocal(desc): \(err.localizedDescription)") }
            }
            self.onLocalOffer?(sdp.sdp, destPeer)
        }
    }

    func addIceCandidate(_ candidate: RTCIceCandidate) {
        peerConnection?.add(candidate) { [weak self] error in
            if let error = error {
                self?.delegate?.rtcError("addIceCandidate: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - RTCPeerConnectionDelegate
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd rtpReceiver: RTCRtpReceiver, streams mediaStreams: [RTCMediaStream]) {
        if let stream = mediaStreams.first {
            remoteStream = stream
        }
        
        let allVideoTracks = peerConnection.transceivers
            .compactMap { $0.receiver.track as? RTCVideoTrack }
        
        delegate?.rtcRemoteVideoTracksReceived(allVideoTracks)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection,
                        didAdd stream: RTCMediaStream) {
        remoteStream = stream
        
        let allVideoTracks = peerConnection.transceivers
            .compactMap { $0.receiver.track as? RTCVideoTrack }
            
        delegate?.rtcRemoteVideoTracksReceived(allVideoTracks.isEmpty ? stream.videoTracks : allVideoTracks)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection,
                        didGenerate candidate: RTCIceCandidate) {
        onIceCandidate?(candidate, candidatePeerId ?? "")
    }

    var candidatePeerId: String?

    func peerConnection(_ peerConnection: RTCPeerConnection,
                        didChange newState: RTCIceConnectionState) {
        let connected = newState == .connected || newState == .completed
        delegate?.rtcConnectStateChanged(connected)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection,
                        didChange stateChanged: RTCSignalingState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection,
                        didRemove stream: RTCMediaStream) {}
    func peerConnection(_ peerConnection: RTCPeerConnection,
                        didChange newState: RTCIceGatheringState) {}
    func peerConnection(_ peerConnection: RTCPeerConnection,
                        didOpen dataChannel: RTCDataChannel) {}
    func peerConnection(_ peerConnection: RTCPeerConnection,
                        didRemove candidates: [RTCIceCandidate]) {}
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}

    func close() {
        peerConnection?.close()
        peerConnection = nil
        socketCapturer?.stop()
        socketCapturer = nil
        localVideoSource = nil
        localAudioTrack = nil
        remoteStream = nil
    }
}