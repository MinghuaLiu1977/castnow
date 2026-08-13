import SwiftUI
import WebRTC

class ReceiveViewModel: NSObject, ObservableObject, WebRTCManagerDelegate {
    @Published var codeInput: String = ""
    @Published var isConnecting: Bool = false
    @Published var isConnected: Bool = false
    @Published var errorMessage: String?
    @Published var remoteTrack: RTCVideoTrack?

    private let rtc = WebRTCManager()
    private let peer = PeerJSClient()
    private var broadcasterId: String?

    override init() {
        super.init()
        rtc.delegate = self
    }

    func join() {
        guard codeInput.count == 6, !isConnecting else { return }
        broadcasterId = codeInput
        isConnecting = true
        errorMessage = nil

        // receiver creates its own peer with a unique id: cnv_... (matches web style)
        let model = UIDevice.current.model.replacingOccurrences(of: " ", with: "")
        let random = Int(Date().timeIntervalSince1970).description.suffix(6)
        let peerId = "cnv_\(model)_iOS_\(random)"

        rtc.createPeerConnection()

        peer.onEvent = { [weak self] event in
            self?.handle(event: event)
        }
        peer.connect(id: peerId)
    }

    func leave() {
        if let dest = broadcasterId { peer.sendLeave(to: dest) }
        peer.disconnect()
        rtc.close()
        isConnected = false
        isConnecting = false
        remoteTrack = nil
    }

    private func handle(event: PeerEvent) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch event {
            case .opened:
                // Send knock offer to broadcaster (v9.1 handshake)
                self.rtc.candidatePeerId = self.broadcasterId
                self.rtc.onLocalOffer = { [weak self] sdp, dest in
                    print("📤 [PeerJS] Knock OFFER → \(dest)")
                    self?.peer.sendOffer(to: dest, sdp: sdp)
                }
                self.rtc.onIceCandidate = { [weak self] candidate, dest in
                    self?.peer.sendCandidate(to: dest,
                                             candidate: candidate.sdp,
                                             sdpMLineIndex: candidate.sdpMLineIndex,
                                             sdpMid: candidate.sdpMid)
                }
                self.rtc.createOffer(destPeer: self.broadcasterId ?? "")

            case .offer(let offer):
                // Broadcaster recalled with their own offer (v9.1 recall).
                // Answer it.
                print("✅ [PeerJS] Recall OFFER from \(offer.sourcePeerId)")
                self.rtc.candidatePeerId = offer.sourcePeerId
                self.rtc.onRemoteOffer = { [weak self] sdp in
                    guard let self = self, let dest = self.broadcasterId else { return }
                    print("📤 [PeerJS] ANSWER → \(dest)")
                    self.peer.sendAnswer(to: dest, sdp: sdp)
                }
                self.rtc.setRemoteDescription(offer.sdp)

            case .answer:
                // Our knock's answer (if any) - ignore, we handle recall above
                break

            case .candidate(let cand):
                self.rtc.addIceCandidate(cand)

            case .close:
                self.isConnected = false
                self.isConnecting = false
                self.errorMessage = "连接已断开"

            case .error(let msg):
                self.errorMessage = msg
                self.isConnecting = false
            }
        }
    }

    func rtcConnectStateChanged(_ connected: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isConnected = connected
            if connected { self?.isConnecting = false }
        }
    }

    func rtcRemoteStreamReceived(_ stream: RTCMediaStream) {
        DispatchQueue.main.async { [weak self] in
            if let track = stream.videoTracks.first {
                self?.remoteTrack = track
            }
        }
    }

    func rtcError(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = message
            self?.isConnecting = false
        }
    }
}

struct ReceiveView: View {
    @StateObject private var vm = ReceiveViewModel()
    @Environment(\.presentationMode) var presentationMode
    @FocusState private var codeFocused: Bool

    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.05, blue: 0.12).ignoresSafeArea()

            if vm.isConnected {
                // 观看画面
                ZStack(alignment: .topLeading) {
                    Color.black.ignoresSafeArea()
                    VideoStreamView(track: vm.remoteTrack)
                        .ignoresSafeArea()

                    Button(action: { vm.leave(); presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .padding(12)
                            .background(Circle().fill(Color.white.opacity(0.2)))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 40)
                    .padding(.leading, 16)
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // 顶部返回
                        HStack {
                            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                                Image(systemName: "chevron.left")
                                    .font(.headline)
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(12)
                                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05)))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        Spacer().frame(height: 60)

                        // 图标 + 标题（上移预留键盘空间）
                        if let ui = UIImage(named: "AppIconImage") {
                            Image(uiImage: ui)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(kPrimary)
                        }

                        Text("输入配对码")
                            .font(.title2.weight(.black))
                            .foregroundColor(.white)
                            .padding(.top, 16)

                        // 6 位输入框
                        HStack(spacing: 8) {
                            ForEach(0..<6, id: \.self) { i in
                                Text(i < vm.codeInput.count ? String(vm.codeInput[vm.codeInput.index(vm.codeInput.startIndex, offsetBy: i)]) : "")
                                    .font(.system(size: 30, weight: .black))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 60)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .strokeBorder(Color.white.opacity(i == vm.codeInput.count ? 0.6 : 0.15), lineWidth: 2)
                                    )
                            }
                        }
                        .padding(.top, 24)

                        // 隐藏输入
                        TextField("", text: $vm.codeInput)
                            .keyboardType(.numberPad)
                            .opacity(0)
                            .focused($codeFocused)
                            .onChange(of: vm.codeInput) { newValue in
                                if newValue.count > 6 { vm.codeInput = String(newValue.prefix(6)) }
                                if newValue.count == 6 && !vm.isConnecting {
                                    vm.join()
                                }
                            }

                        Button(action: { vm.join() }) {
                            HStack {
                                if vm.isConnecting {
                                    ProgressView().tint(.black)
                                } else {
                                    Text("立即连接").fontWeight(.heavy)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(RoundedRectangle(cornerRadius: 20).fill(vm.codeInput.count == 6 ? Color(red: 0.2, green: 0.8, blue: 1.0) : Color.white.opacity(0.1)))
                            .foregroundColor(vm.codeInput.count == 6 ? .black : .white.opacity(0.4))
                        }
                        .disabled(vm.codeInput.count != 6 || vm.isConnecting)
                        .padding(.top, 32)

                        if let msg = vm.errorMessage {
                            Text(msg).font(.footnote).foregroundColor(.red)
                                .padding(.top, 12)
                        }

                        if vm.isConnecting {
                            Text("正在连接...").font(.footnote).foregroundColor(.white.opacity(0.5))
                                .padding(.top, 12)
                        }

                        // 底部留白，确保键盘弹出时内容不被遮挡
                        Spacer().frame(height: 120)
                    }
                    .padding(.horizontal, 32)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear { codeFocused = true }
        .onDisappear { if !vm.isConnected { vm.leave() } }
        .onTapGesture { codeFocused = true }
    }
}

#Preview { ReceiveView() }