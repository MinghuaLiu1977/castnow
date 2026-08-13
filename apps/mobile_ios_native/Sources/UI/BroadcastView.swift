import SwiftUI
import WebRTC
import ReplayKit

class BroadcastViewModel: NSObject, ObservableObject, WebRTCManagerDelegate {
    @Published var pairCode: String = ""
    @Published var isConnected: Bool = false
    @Published var statusMessage: String = "连接中..."
    @Published var started: Bool = false

    let shareScreen: Bool
    let shareCamera: Bool
    let shareMic: Bool

    private let rtc = WebRTCManager()
    private let peer = PeerJSClient()
    private var destPeer: String?

    init(shareScreen: Bool, shareCamera: Bool, shareMic: Bool) {
        self.shareScreen = shareScreen
        self.shareCamera = shareCamera
        self.shareMic = shareMic
        super.init()
        rtc.delegate = self
    }

    func start() {
        let code = String(format: "%06d", Int.random(in: 100000...999999))
        pairCode = code

        rtc.createPeerConnection()
        if shareScreen {
            let source = rtc.startScreenCapture()
            if let track = rtc.addVideoTrack() { rtc.attachBroadcastTrack(track) }
        }

        peer.onEvent = { [weak self] event in self?.handle(event: event) }
        peer.connect(id: code)
    }

    func stop() {
        if let d = destPeer { peer.sendLeave(to: d) }
        peer.disconnect()
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
                self.statusMessage = "信令已连接 (\(id))"
            case .offer(let offer):
                self.destPeer = offer.sourcePeerId
                self.rtc.candidatePeerId = offer.sourcePeerId
                self.rtc.onRemoteOffer = { [weak self] sdp in self?.peer.sendAnswer(to: offer.sourcePeerId, sdp: sdp) }
                self.rtc.setRemoteDescription(offer.sdp)
            case .candidate(let c):
                self.rtc.addIceCandidate(c)
            case .close:
                self.isConnected = false
                self.statusMessage = "接收端已离开"
            case .answer, .error:
                break
            }
        }
    }

    func rtcConnectStateChanged(_ connected: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isConnected = connected
            self?.statusMessage = connected ? "已连接" : "等待接收端..."
        }
    }
    func rtcRemoteStreamReceived(_ stream: RTCMediaStream) {}
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
                        VStack(spacing: 12) {
                            Image(systemName: vm.shareScreen ? "rectangle.on.rectangle" : "video.fill")
                                .font(.system(size: 48))
                                .foregroundColor(kPrimary)
                            Text(vm.shareScreen ? "屏幕镜像运行中" : "摄像头画面")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    )
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

                // 操作按钮
                VStack(spacing: 16) {
                    if !vm.started {
                        Button(action: { vm.beginSystemBroadcast() }) {
                            Text("启动系统屏幕共享")
                                .font(.system(size: 16, weight: .black))
                                .foregroundColor(.black)
                                .frame(maxWidth: 320)
                                .padding(.vertical, 18)
                                .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(kPrimary))
                        }
                    }
                    Button(action: { vm.stop(); presentationMode.wrappedValue.dismiss() }) {
                        Text("结束投屏")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.red)
                            .frame(maxWidth: 320)
                            .padding(.vertical, 16)
                            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.red.opacity(0.12)))
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .navigationBarHidden(true)
        .onAppear { vm.start() }
        .onDisappear { vm.stop() }
    }
}

#Preview { BroadcastView(shareScreen: true, shareCamera: false, shareMic: true) }