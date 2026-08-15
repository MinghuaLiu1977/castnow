import SwiftUI
import WebRTC
import ReplayKit
import AVFoundation

/// Renders the AVCapture preview layer.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewHostView {
        let v = PreviewHostView()
        v.bind(session: session)
        return v
    }
    func updateUIView(_ uiView: PreviewHostView, context: Context) {
        uiView.bind(session: session)
    }
    final class PreviewHostView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        private var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        func bind(session: AVCaptureSession) {
            if previewLayer.session !== session {
                previewLayer.session = session
                previewLayer.videoGravity = .resizeAspect
            }
        }
    }
}

class BroadcastViewModel: NSObject, ObservableObject, WebRTCManagerDelegate {
    @Published var pairCode: String = ""
    @Published var isConnected: Bool = false
    @Published var statusMessage: String = "连接中..."
    @Published var started: Bool = false
    @Published var previewImage: UIImage?
    @Published var isMicMuted: Bool = true
    @Published var isPlaybackMuted: Bool = false

    var onDisconnect: (() -> Void)?

    /// 正在主动停止（锁屏/退出页面）。此时忽略信令 close，避免重复弹窗。
    private(set) var isStopping = false

    private var pendingCode: String = ""

    let shareScreen: Bool
    let shareCamera: Bool
    let shareMic: Bool

    private let rtc = WebRTCManager()
    private let peer = PeerJSClient()
    @Published private(set) var camera: CameraCapture?
    private var destPeer: String?
    private var pendingCamera: CameraCapture?

    private var isPeerReady: Bool = false { didSet { checkReady() } }
    private var isCameraReady: Bool = false { didSet { checkReady() } }

    private func checkReady() {
        if isPeerReady && isCameraReady {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if self.pairCode.isEmpty {
                    self.pairCode = self.pendingCode
                    self.statusMessage = "等待接收端..."
                    print("✅ [Broadcast] Code displayed: \(self.pairCode)")
                }
            }
        }
    }

    @Published var localVideoTrack: RTCVideoTrack?

    init(shareScreen: Bool, shareCamera: Bool, shareMic: Bool) {
        self.shareScreen = shareScreen
        self.shareCamera = shareCamera
        self.shareMic = shareMic
        super.init()
        rtc.delegate = self
    }

    func start() {
        statusMessage = "正在初始化设备..."
        rtc.startBackgroundKeeper()
        peer.onEvent = { [weak self] event in self?.handle(event: event) }

        let code = String(format: "%06d", Int.random(in: 100000...999999))
        pendingCode = code
        print("📞 [Broadcast] Registering as peerId=\(code)")
        peer.connect(id: code)

        if shareCamera {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                let cam = CameraCapture(factory: self.rtc.factory)
                cam.configure()
                
                DispatchQueue.main.async {
                    self.pendingCamera = cam
                    cam.onStarted = { [weak self, weak cam] in
                        guard let self = self, let cam = cam else { return }
                        self.camera = cam
                        self.localVideoTrack = self.rtc.factory.videoTrack(with: cam.videoSource, trackId: "camera_local_preview")
                        self.pendingCamera = nil
                        self.isCameraReady = true
                        self.checkReady()
                    }
                    cam.start()
                }
            }
        } else if shareScreen {
            _ = rtc.startScreenCapture()
            rtc.setScreenPreviewHandler { [weak self] img in self?.previewImage = img }
            // 锁屏/控制中心停止/Extension 崩溃 → socket 断开 → 完整清理 P2P + 信令
            rtc.setBroadcastEndedHandler { [weak self] in
                DispatchQueue.main.async {
                    guard let self = self, !self.isStopping else { return }
                    print("🛑 [Broadcast] Broadcast ended by system → full teardown")
                    self.statusMessage = "直播已结束"
                    self.stop()
                    self.onDisconnect?()
                }
            }
            isCameraReady = true
        } else {
            isCameraReady = true
        }
    }

    func toggleMic() {
        isMicMuted.toggle()
        rtc.enableLocalMicrophone(!isMicMuted)
    }

    func togglePlayback() {
        isPlaybackMuted.toggle()
        rtc.enableRemoteSpeaker(!isPlaybackMuted)
    }

    func flipCamera() {
        camera?.flip()
    }

    func stop() {
        isStopping = true
        if let d = destPeer { peer.sendLeave(to: d) }
        peer.disconnect()
        camera?.stop()
        pendingCamera?.stop()
        camera = nil
        pendingCamera = nil
        rtc.close()
    }


    @Published var triggerSystemBroadcast = false

    func beginSystemBroadcast() {
        triggerSystemBroadcast = true
        started = true
    }

    private func handle(event: PeerEvent) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch event {
            case .opened(let id):
                // PeerJS server confirmed registration — NOW wait for camera
                self.isPeerReady = true
                print("✅ [Broadcast] Registered with PeerJS: \(id)")
                if self.shareScreen { self.beginSystemBroadcast() }

            case .offer(let offer):
                guard self.destPeer == nil else { return }
                self.destPeer = offer.sourcePeerId
                print("📥 [Broadcast] OFFER from \(offer.sourcePeerId), triggering recall")
                self.statusMessage = "接收端已连接"
                self.peer.resetConnectionId()
                self.recall(to: offer.sourcePeerId)

            case .answer(let answer):
                print("✅ [PeerJS] Answer from receiver")
                self.rtc.setRemoteDescription(answer.sdp, type: .answer)

            case .candidate(let c):
                self.rtc.addIceCandidate(c)

            case .close:
                // 主动停止（锁屏/退出）中：不处理，由调用方负责退出页面
                if self.isStopping { break }
                // Only show "receiver left" if we were actually connected.
                // Knock/close during handshake is normal, ignore it.
                if self.isConnected {
                    self.isConnected = false
                    self.statusMessage = "接收端已离开"
                    self.onDisconnect?()
                } else {
                    print("ℹ️ [PeerJS] Close during handshake, ignored")
                }
            case .error(let msg):
                self.statusMessage = "错误: \(msg)"
            }
        }
    }

    private func recall(to receiverId: String) {
        statusMessage = "回拨接收端..."
        print("📞 [PeerJS] Recalling \(receiverId)")

        // Fresh PC + tracks for recall
        rtc.createPeerConnection()
        rtc.setupLocalAudio()
        rtc.enableLocalMicrophone(!isMicMuted)
        rtc.enableRemoteSpeaker(!isPlaybackMuted)

        if shareScreen {
            if let track = rtc.addVideoTrack() { rtc.attachBroadcastTrack(track) }
        }
        if shareCamera {
            if let cam = camera {
                let track = rtc.factory.videoTrack(with: cam.videoSource, trackId: "camera0")
                rtc.attachBroadcastTrack(track)
            }
        }

        // Create our own offer and send to receiver
        rtc.candidatePeerId = receiverId
        rtc.onLocalOffer = { [weak self] sdp, dest in
            print("📤 [PeerJS] Recall OFFER → \(dest)")
            self?.peer.sendOffer(to: dest, sdp: sdp)
        }
        rtc.onIceCandidate = { [weak self] candidate, dest in
            self?.peer.sendCandidate(to: dest,
                                     candidate: candidate.sdp,
                                     sdpMLineIndex: candidate.sdpMLineIndex,
                                     sdpMid: candidate.sdpMid)
        }
        rtc.createOffer(destPeer: receiverId)
    }

    func rtcConnectStateChanged(_ connected: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard !self.isStopping else { return }
            let wasConnected = self.isConnected
            self.isConnected = connected
            self.statusMessage = connected ? "已连接" : "等待接收端..."
            
            if connected {
                // 关键修复：recall() 时调用 enableRemoteSpeaker/enableLocalMicrophone时，
                // ICE 还没建立完成， transceivers 为空，调用无效。
                // 必须在 ICE connected 之后再次应用，才能真正开启/关闭音频轨道。
                self.rtc.enableRemoteSpeaker(!self.isPlaybackMuted)
                self.rtc.enableLocalMicrophone(!self.isMicMuted)
                print("🔊 [Broadcast] ICE connected → speaker=\(!self.isPlaybackMuted), mic=\(!self.isMicMuted)")
            }
            
            if wasConnected && !connected {
                self.onDisconnect?()
            }
        }
    }
    func rtcRemoteVideoTracksReceived(_ tracks: [RTCVideoTrack]) {
        // Broadcast side does not display remote video
    }
    func rtcError(_ message: String) {
        DispatchQueue.main.async { [weak self] in self?.statusMessage = "错误: \(message)" }
    }
}

struct BroadcastView: View {
    @StateObject private var vm: BroadcastViewModel
    @Environment(\.presentationMode) var presentationMode

    init(shareScreen: Bool, shareCamera: Bool, shareMic: Bool) {
        _vm = StateObject(wrappedValue: BroadcastViewModel(shareScreen: shareScreen, shareCamera: shareCamera, shareMic: shareMic))
    }

    var body: some View {
        ZStack {
            kBackground.ignoresSafeArea()

            if let ext = Bundle.main.object(forInfoDictionaryKey: "RTCScreenSharingExtension") as? String {
                SystemBroadcastPickerView(extensionBundleId: ext, trigger: $vm.triggerSystemBroadcast)
                    .frame(width: 0, height: 0)
            }

            VStack(spacing: 0) {
                // 状态条
                HStack(spacing: 8) {
                    Circle().fill(vm.isConnected ? Color.green : Color.blue).frame(width: 8, height: 8)
                    Text(vm.statusMessage).font(.system(size: 13, weight: .semibold)).foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Button(action: { vm.stop(); presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark").font(.headline).foregroundColor(.white)
                            .padding(10).background(Circle().fill(Color.white.opacity(0.1)))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                // 预览区
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(red: 0.059, green: 0.090, blue: 0.165))
                    .frame(height: 220)
                    .overlay(
                        Group {
                            if let img = vm.previewImage {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            } else if vm.shareCamera, let cam = vm.camera {
                                CameraPreview(session: cam.captureSession)
                                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            } else {
                                VStack(spacing: 16) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: kPrimary))
                                        .scaleEffect(1.4)
                                    Text(vm.shareScreen ? "正在启动屏幕共享..." : "正在启动摄像头...")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.8))
                                    if vm.shareScreen {
                                        Text("请在系统弹窗中点击「开始直播」")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                }
                            }
                        }
                    )
                    .clipped()
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                // 投屏码
                VStack(spacing: 8) {
                    Text("投屏配对码")
                        .font(.system(size: 11, weight: .bold)).tracking(2)
                        .foregroundColor(.white.opacity(0.5))
                    Text(vm.pairCode.isEmpty ? "------" : vm.pairCode)
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundColor(kPrimary)
                        .kerning(8)
                }
                .padding(.top, 24)

                // 接收提示
                HStack(spacing: 10) {
                    Image(systemName: "info.circle").font(.system(size: 16)).foregroundColor(kPrimary)
                    Text("打开 ")
                        .font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.7))
                    + Text("castnow.padap.cn").font(.system(size: 12, weight: .bold)).foregroundColor(kPrimary).underline()
                    + Text(" 接收").font(.system(size: 12, weight: .medium)).foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white.opacity(0.06)))
                .padding(.top, 20)

                Spacer()

                // 操作栏 + 结束投屏
                VStack(spacing: 16) {
                    HStack(spacing: 0) {
                        if vm.shareMic {
                            controlButton(
                                icon: vm.isMicMuted ? "mic.slash.fill" : "mic.fill",
                                label: vm.isMicMuted ? "已静音" : "麦克风",
                                tint: vm.isMicMuted ? .red : .white
                            ) { vm.toggleMic() }
                        }
                        controlButton(
                            icon: vm.isPlaybackMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                            label: vm.isPlaybackMuted ? "声音关" : "声音",
                            tint: vm.isPlaybackMuted ? .white.opacity(0.4) : kPrimary
                        ) { vm.togglePlayback() }
                        if vm.shareCamera {
                            controlButton(
                                icon: "camera.rotate",
                                label: "翻转",
                                tint: .white
                            ) { vm.flipCamera() }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color.white.opacity(0.06)))
                    .frame(maxWidth: 320)

                    Button(action: { vm.stop(); presentationMode.wrappedValue.dismiss() }) {
                        Text("结束投屏")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.red)
                            .frame(maxWidth: 320)
                            .padding(.vertical, 16)
                            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.red.opacity(0.12)))
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            vm.onDisconnect = {
                presentationMode.wrappedValue.dismiss()
            }
            vm.start()
            // 投屏期间退到后台不停止：ReplayKit 采集在后台持续运行，
            // WebRTC 由 audio background mode 保活。仅在用户主动点结束时断开。
        }
        .onDisappear { vm.stop() }
    }

    private func controlButton(icon: String, label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 22)).foregroundColor(tint)
                Text(label).font(.system(size: 10, weight: .bold)).foregroundColor(tint.opacity(0.9))
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview { BroadcastView(shareScreen: true, shareCamera: false, shareMic: true) }

import ReplayKit

struct SystemBroadcastPickerView: UIViewRepresentable {
    let extensionBundleId: String
    @Binding var trigger: Bool

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 4, height: 4))
        view.backgroundColor = .clear
        // 不能用 isHidden：部分 iOS 版本隐藏视图不响应 sendActions
        view.alpha = 0.01

        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 4, height: 4))
        picker.preferredExtension = extensionBundleId
        picker.showsMicrophoneButton = false
        view.addSubview(picker)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if trigger {
            DispatchQueue.main.async {
                if let picker = uiView.subviews.first(where: { $0 is RPSystemBroadcastPickerView }) as? RPSystemBroadcastPickerView {
                    if let button = picker.subviews.first(where: { $0 is UIButton }) as? UIButton {
                        button.sendActions(for: .touchUpInside)
                    }
                }
                trigger = false
            }
        }
    }
}