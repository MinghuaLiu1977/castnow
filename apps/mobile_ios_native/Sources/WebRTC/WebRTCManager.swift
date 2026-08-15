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
    private var pendingRemoteCandidates: [RTCIceCandidate] = []

    override init() {
        // 必须先设 category 为 playAndRecord，defaultToSpeaker 才合法（否则 SessionCore.mm 报错刷屏）
        let config = RTCAudioSessionConfiguration.webRTC()
        config.category = .playAndRecord
        config.categoryOptions = [.defaultToSpeaker, .allowBluetoothHFP, .allowBluetoothA2DP]
        config.mode = .voiceChat
        RTCAudioSessionConfiguration.setWebRTC(config)

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
        // 明确告知编码器目标分辨率/帧率，防止默认低分辨率（模糊根因）
        source.adaptOutputFormat(toWidth: 1280, height: 720, fps: 22)
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
        peerConnection?.add(track, streamIds: ["castnow_stream"])
        // Audio track is added separately via setupLocalAudio()
        // Do NOT add it here again to avoid duplicate transceivers
    }

    func setScreenPreviewHandler(_ handler: @escaping (UIImage) -> Void) {
        socketCapturer?.onPreviewFrame = handler
    }

    var onRemoteOffer: ((String) -> Void)?

    // MARK: - Audio Configuration
    
    /// Sets up local microphone audio track and immediately adds it to the peer connection.
    /// Call this AFTER createPeerConnection() so the track is registered in the SDP offer/answer.
    func setupLocalAudio() {
        guard localAudioTrack == nil else { return }
        
        let audioConstrains = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let audioSource = factory.audioSource(with: audioConstrains)
        let audioTrack = factory.audioTrack(with: audioSource, trackId: "audio_mic")
        
        self.localAudioTrack = audioTrack
        
        // Add to peer connection immediately so it's negotiated in the SDP.
        peerConnection?.add(audioTrack, streamIds: ["castnow_stream"])
        
        // Start muted by default — user must explicitly unmute via the mic button
        audioTrack.isEnabled = false
        print("🎙 [WebRTC] setupLocalAudio: track=\(audioTrack.trackId), enabled=\(audioTrack.isEnabled)")
    }
    
    func enableLocalMicrophone(_ enabled: Bool) {
        guard let track = localAudioTrack else {
            print("🎙 [WebRTC] enableLocalMicrophone(\(enabled)): ⚠️ localAudioTrack is nil!")
            return
        }
        track.isEnabled = enabled
        print("🎙 [WebRTC] enableLocalMicrophone → \(enabled), trackId=\(track.trackId)")
    }
    
    /// Enables or disables the remote audio received from the web receiver.
    func enableRemoteSpeaker(_ enabled: Bool) {
        let transceivers = peerConnection?.transceivers ?? []
        print("🔊 [WebRTC] enableRemoteSpeaker(\(enabled)): transceivers=\(transceivers.count), remoteAudioTracks=\(remoteStream?.audioTracks.count ?? 0)")
        
        // Enable via remoteStream audio tracks
        remoteStream?.audioTracks.forEach { track in
            track.isEnabled = enabled
            print("🔊 [WebRTC]   remoteStream audioTrack id=\(track.trackId) → \(enabled)")
        }
        
        // Also enable via transceivers (unified-plan)
        for transceiver in transceivers {
            if let audioTrack = transceiver.receiver.track as? RTCAudioTrack {
                audioTrack.isEnabled = enabled
                print("🔊 [WebRTC]   transceiver audioTrack id=\(audioTrack.trackId) → \(enabled)")
            }
        }
        
        if transceivers.filter({ $0.receiver.track is RTCAudioTrack }).isEmpty && (remoteStream?.audioTracks.isEmpty ?? true) {
            print("🔊 [WebRTC]   ⚠️ No remote audio tracks found — will be applied again on ICE connected")
        }
    }

    // MARK: - Receiver: answer incoming offer

    func setRemoteDescription(_ sdp: String, type: RTCSdpType) {
        let desc = RTCSessionDescription(type: type, sdp: sdp)
        peerConnection?.setRemoteDescription(desc) { [weak self] error in
            if let error = error {
                self?.delegate?.rtcError("setRemoteDescription: \(error.localizedDescription)")
                return
            }
            if type == .offer {
                self?.createAnswer()
            }
            
            // Drain any pending ICE candidates received before the remote description was set
            if let pending = self?.pendingRemoteCandidates {
                self?.pendingRemoteCandidates.removeAll()
                for candidate in pending {
                    self?.addIceCandidate(candidate)
                }
            }
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
        if peerConnection?.remoteDescription == nil {
            pendingRemoteCandidates.append(candidate)
        } else {
            peerConnection?.add(candidate) { [weak self] error in
                if let error = error {
                    self?.delegate?.rtcError("addIceCandidate: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - RTCPeerConnectionDelegate
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd rtpReceiver: RTCRtpReceiver, streams mediaStreams: [RTCMediaStream]) {
        print("📡 [WebRTC] didAdd rtpReceiver: kind=\(rtpReceiver.track?.kind ?? "nil"), trackId=\(rtpReceiver.track?.trackId ?? "nil"), streams=\(mediaStreams.count)")
        
        if let stream = mediaStreams.first {
            remoteStream = stream
            print("📡 [WebRTC]   attached to stream: video=\(stream.videoTracks.count), audio=\(stream.audioTracks.count)")
        }
        
        let allVideoTracks = peerConnection.transceivers
            .compactMap { $0.receiver.track as? RTCVideoTrack }
        
        delegate?.rtcRemoteVideoTracksReceived(allVideoTracks)
        
        // 收到远端 audio track 时，立即启用
        if let audioTrack = rtpReceiver.track as? RTCAudioTrack {
            audioTrack.isEnabled = true
            print("🔊 [WebRTC]   ✅ Remote audio track ENABLED: id=\(audioTrack.trackId), enabled=\(audioTrack.isEnabled)")
        }
        
        let audioTracks = peerConnection.transceivers
            .compactMap { $0.receiver.track as? RTCAudioTrack }
        print("📡 [WebRTC]   Total transceivers: video=\(allVideoTracks.count), audio=\(audioTracks.count)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection,
                        didAdd stream: RTCMediaStream) {
        remoteStream = stream
        print("📡 [WebRTC] didAdd stream: video=\(stream.videoTracks.count), audio=\(stream.audioTracks.count)")
        
        // 同样启用 stream 里的 audio tracks
        stream.audioTracks.forEach { track in
            track.isEnabled = true
            print("🔊 [WebRTC]   stream audioTrack \(track.trackId) ENABLED")
        }
        
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
        print("🔗 [WebRTC] ICE state: \(newState.rawValue), connected=\(connected)")
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