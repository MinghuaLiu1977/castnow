import SwiftUI
import WebRTC
import ReplayKit
import AVFoundation

/// Renders the AVCapture preview layer.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewHostView {
        let v = PreviewHostView()
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
                previewLayer.videoGravity = .resizeAspectFill
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

    private var pendingCode: String = ""

    let shareScreen: Bool
    let shareCamera: Bool
    let shareMic: Bool

    private let rtc = WebRTCManager()
    private let peer = PeerJSClient()
    private var camera: CameraCapture?
    private var destPeer: String?

    var cameraSession: AVCaptureSession? { camera?.captureSession }

    init(shareScreen: Bool, shareCamera: Bool, shareMic: Bool) {
        self.shareScreen = shareScreen
        self.shareCamera = shareCamera
        self.shareMic = shareMic
        super.init()
        rtc.delegate = self
    }

    func start() {
        statusMessage = "正在连接信令服务器..."
        peer.onEvent = { [weak self] event in self?.handle(event: event) }

        let code = String(format: "%06d", Int.random(in: 100000...999999))
        pendingCode = code
        print("📞 [Broadcast] Registering as peerId=\(code)")
        peer.connect(id: code)
    }

    func toggleMic() {
        isMicMuted.toggle()
    }

    func togglePlayback() {
        isPlaybackMuted.toggle()
    }

    func flipCamera() {
        // TODO: switch camera front/back
    }

    func stop() {
        if let d = destPeer { peer.sendLeave(to: d) }
        peer.disconnect()
        camera?.stop()
        camera = nil
        rtc.close()
    }

    func beginSystemBroadcast() {
        guard let ext = Bundle.main.object(forInfoDictionaryKey: "RTCScreenSharingExtension") as? String else { return }
        DispatchQueue.main.async {
            let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
            picker.preferredExtension = ext
            picker.showsMicrophoneButton = true
            picker.alpha = 0.01
            if let host = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).flatMap({ $0.windows }).first(where: { $0.isKeyWindow })?.rootViewController {
                picker.center = host.view.center
                host.view.addSubview(picker)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { picker.removeFromSuperview() }
            }
        }
        started = true
    }

    private func handle(event: PeerEvent) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch event {
            case .opened(let id):
                // PeerJS server confirmed registration — NOW show the code
                self.pairCode = self.pendingCode
                self.statusMessage = "信令已连接 (\(id))"
                print("✅ [Broadcast] Code displayed: \(self.pairCode)")
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
                self.rtc.setRemoteDescription(answer.sdp)

            case .candidate(let c):
                self.rtc.addIceCandidate(c)

            case .close:
                // Only show "receiver left" if we were actually connected.
                // Knock/close during handshake is normal, ignore it.
                if self.isConnected {
                    self.isConnected = false
                    self.statusMessage = "接收端已离开"
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

        if shareScreen {
            let source = rtc.startScreenCapture()
            if let track = rtc.addVideoTrack() { rtc.attachBroadcastTrack(track) }
            rtc.setScreenPreviewHandler { [weak self] img in self?.previewImage = img }
        }
        if shareCamera {
            let cam = CameraCapture(factory: rtc.factory)
            cam.configure()
            cam.start()
            camera = cam
            let track = rtc.factory.videoTrack(with: cam.videoSource, trackId: "camera0")
            rtc.attachBroadcastTrack(track)
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
            self?.isConnected = connected
            self?.statusMessage = connected ? "已连接" : "等待接收端..."
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
                            } else if vm.shareCamera, let session = vm.cameraSession {
                                CameraPreview(session: session)
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
        .onAppear { vm.start() }
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