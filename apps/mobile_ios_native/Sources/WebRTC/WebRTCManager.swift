import Foundation
import WebRTC

enum WebrtcRole {
    case broadcaster
    case receiver
}

/// 后台保活：循环播放静音，维持 audio session 活跃。
/// 麦克风静音时 WebRTC 不会激活 session，App 后台数秒内被挂起导致直播中断。
final class BackgroundAudioKeeper {
    private var player: AVAudioPlayer?

    /// 生成 1 秒静音 WAV（PCM16 mono）
    private static func silentWav(sampleRate: Int = 24000) -> Data {
        let frames = sampleRate
        var data = Data(capacity: 44 + frames * 2)
        func append<T>(_ value: T) { withUnsafeBytes(of: value) { data.append(contentsOf: $0) } }
        append(UInt32(0x46464952))                       // "RIFF"
        append(UInt32(36 + frames * 2))
        append(UInt32(0x45564157))                       // "WAVE"
        append(UInt32(0x20746d66))                       // "fmt "
        append(UInt32(16))
        append(UInt16(1))                                // PCM
        append(UInt16(1))                                // mono
        append(UInt32(sampleRate))
        append(UInt32(sampleRate * 2))                   // byte rate
        append(UInt16(2))                                // block align
        append(UInt16(16))                               // bits
        append(UInt32(0x61746164))                       // "data"
        append(UInt32(frames * 2))
        data.append(Data(count: frames * 2))
        return data
    }

    func start() {
        guard player == nil else { return }
        // 音频会话被其他 App 抢占（interruption）后自动恢复保活
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification,
                                               object: nil, queue: .main) { [weak self] note in
            let type = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            if type == AVAudioSession.InterruptionType.ended.rawValue {
                print("🔊 [Keeper] Interruption ended → restart")
                self?.restartPlayback()
            }
        }
        // 音频子系统崩溃/重置后自动恢复
        NotificationCenter.default.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            print("🔊 [Keeper] Media services reset → restart")
            self?.player = nil
            self?.restartPlayback()
        }
        restartPlayback()
    }

    private func restartPlayback() {
        do {
            try AVAudioSession.sharedInstance().setActive(true, options: [])
        } catch {
            print("⚠️ [Keeper] setActive failed: \(error)")
        }
        do {
            let p = try AVAudioPlayer(data: Self.silentWav())
            p.numberOfLoops = -1
            // volume 0 会被 iOS 判定“未产生音频”而照常挂起；0.05 听不见但保活有效
            p.volume = 0.05
            p.play()
            player = p
            print("🔊 [Keeper] Silent background audio started (vol 0.05)")
        } catch {
            print("⚠️ [Keeper] Silent audio failed: \(error)")
        }
    }

    func stop() {
        NotificationCenter.default.removeObserver(self)
        player?.stop()
        player = nil
    }
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
    private let keeper = BackgroundAudioKeeper()

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
        config.category = AVAudioSession.Category.playAndRecord.rawValue
        // mixWithOthers：与其他 App 音频混音而非抢占——被抢占会中断保活播放，
        // App 随即被挂起/杀死（投屏中断的根因）。voiceChat 软件回声消除不受影响。
        config.categoryOptions = [.defaultToSpeaker, .allowBluetoothHFP, .allowBluetoothA2DP, .mixWithOthers]
        config.mode = AVAudioSession.Mode.voiceChat.rawValue
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
        keeper.start()
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

    /// 广播开始即启动后台保活（音频 session 活跃才不被挂起）
    func startBackgroundKeeper() {
        keeper.start()
    }

    func startScreenCapture() -> RTCVideoSource {
        keeper.start()
        let source = factory.videoSource()
        // 1080p 竖屏（1080x1920）：H264 硬编下已验证可出图的步进升级路径
        source.adaptOutputFormat(toWidth: 1080, height: 1920, fps: 15)
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
        // 屏幕投屏强制 VP8（软编码）：H264 硬编在 App 退后台后失去 GPU 访问，
        // 视频 RTP 停发（音频正常视频冻结的根因）。VP8 纯 CPU，后台可持续编码。
        if let transceiver = peerConnection?.transceivers.first(where: { $0.sender.track?.trackId == track.trackId }) {
            let vp8 = factory.rtpSenderCapabilities(forKind: kRTCMediaStreamTrackKindVideo)
                .codecs.filter { $0.name.lowercased() == "vp8" }
            if !vp8.isEmpty {
                try? transceiver.setCodecPreferences(vp8, error: ())
                print("🎥 [WebRTC] Forced VP8 for screen track (background-safe)")
            }
        }
    }

    func setScreenPreviewHandler(_ handler: @escaping (UIImage) -> Void) {
        socketCapturer?.onPreviewFrame = handler
    }

    /// Broadcast ended by the system (lock screen / control center stop / extension crash).
    func setBroadcastEndedHandler(_ handler: @escaping () -> Void) {
        socketCapturer?.onBroadcastEnded = handler
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

    /// SDP munging: 提升视频码率，防止编码器降级到低分辨率
    private func boostVideoBitrate(_ sdp: String) -> String {
        var lines = sdp.components(separatedBy: "\r\n")
        var result: [String] = []
        var inVideoSection = false

        for line in lines {
            if line.hasPrefix("m=video") {
                inVideoSection = true
                result.append(line)
                // b= 行紧跟 m= 行（SDP 规范），限制视频带宽 6Mbps（H264 硬编可扛）
                result.append("b=AS:6000")
                continue
            } else if line.hasPrefix("m=") {
                inVideoSection = false
            }

            if inVideoSection && line.hasPrefix("a=fmtp:") {
                if line.contains("x-google-max-bitrate") {
                    result.append(line)
                } else {
                    result.append(line + ";x-google-max-bitrate=6000;x-google-start-bitrate=2000")
                }
            } else {
                result.append(line)
            }
        }
        return result.joined(separator: "\r\n")
    }

    private func createAnswer() {
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        peerConnection?.answer(for: constraints) { [weak self] sdp, error in
            guard let self = self, let sdp = sdp else {
                self?.delegate?.rtcError("answer failed: \(error?.localizedDescription ?? "")")
                return
            }
            let boosted = RTCSessionDescription(type: sdp.type, sdp: self.boostVideoBitrate(sdp.sdp))
            self.peerConnection?.setLocalDescription(boosted) { err in
                if let err = err { self.delegate?.rtcError("setLocal(desc): \(err.localizedDescription)") }
            }
            self.onRemoteOffer?(boosted.sdp)
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
            let boosted = RTCSessionDescription(type: sdp.type, sdp: self.boostVideoBitrate(sdp.sdp))
            self.peerConnection?.setLocalDescription(boosted) { err in
                if let err = err { self.delegate?.rtcError("setLocal(desc): \(err.localizedDescription)") }
            }
            self.onLocalOffer?(boosted.sdp, destPeer)
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
        keeper.stop()
        peerConnection?.close()
        peerConnection = nil
        socketCapturer?.stop()
        socketCapturer = nil
        localVideoSource = nil
        localAudioTrack = nil
        remoteStream = nil
    }
}