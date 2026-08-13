import SwiftUI
import WebRTC

class ReceiveViewModel: NSObject, ObservableObject, WebRTCManagerDelegate {
    @Published var codeInput: String = ""
    @Published var isConnecting: Bool = false
    @Published var isConnected: Bool = false
    @Published var errorMessage: String?
    @Published var videoTracks: [RTCVideoTrack] = []
    
    // Audio State
    @Published var isMicEnabled: Bool = false
    @Published var isSpeakerEnabled: Bool = true
    
    // UI Layout State
    @Published var isPiPViewSwapped: Bool = false

    private let rtc = WebRTCManager()
    private let peer = PeerJSClient()
    private var broadcasterId: String?

    override init() {
        super.init()
        rtc.delegate = self
    }
    
    func toggleMic() {
        isMicEnabled.toggle()
        rtc.enableLocalMicrophone(isMicEnabled)
    }
    
    func toggleSpeaker() {
        isSpeakerEnabled.toggle()
        rtc.enableRemoteSpeaker(isSpeakerEnabled)
    }
    
    func swapPiPView() {
        if videoTracks.count > 1 {
            isPiPViewSwapped.toggle()
        }
    }

    func join() {
        guard codeInput.count == 6, !isConnecting else { return }
        broadcasterId = codeInput
        isConnecting = true
        errorMessage = nil
        isMicEnabled = false
        isSpeakerEnabled = true
        isPiPViewSwapped = false

        // receiver creates its own peer with a unique id: cnv_... (matches web style)
        let model = UIDevice.current.model.replacingOccurrences(of: " ", with: "")
        let random = Int(Date().timeIntervalSince1970).description.suffix(6)
        let peerId = "cnv_\(model)_iOS_\(random)"

        rtc.createPeerConnection()
        rtc.setupLocalAudio()

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
        videoTracks.removeAll()
        isMicEnabled = false
        isSpeakerEnabled = true
        isPiPViewSwapped = false
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
                
                // Reset the RTCPeerConnection to avoid 'have-local-offer' state conflict
                self.rtc.close()
                self.rtc.createPeerConnection()
                
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

    func rtcRemoteVideoTracksReceived(_ tracks: [RTCVideoTrack]) {
        DispatchQueue.main.async { [weak self] in
            self?.videoTracks = tracks
        }
    }

    func rtcError(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = message
            self?.isConnecting = false
        }
    }
}

struct DraggablePiPView: View {
    let track: RTCVideoTrack
    let onTap: () -> Void
    
    @State private var offset: CGSize = .zero
    @State private var scale: CGFloat = 1.0
    
    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var magnifyScale: CGFloat = 1.0

    var body: some View {
        VideoStreamView(track: track)
            .frame(width: 120 * scale * magnifyScale, height: 160 * scale * magnifyScale)
            .cornerRadius(12)
            .shadow(radius: 8)
            .offset(x: offset.width + dragOffset.width, y: offset.height + dragOffset.height)
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation
                    }
                    .onEnded { value in
                        let newWidth = offset.width + value.translation.width
                        let newHeight = offset.height + value.translation.height
                        // Basic edge snapping logic could be added here, for now we just accumulate
                        withAnimation(.spring()) {
                            offset = CGSize(width: newWidth, height: newHeight)
                        }
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .updating($magnifyScale) { value, state, _ in
                        state = value
                    }
                    .onEnded { value in
                        let newScale = scale * value
                        // Clamp the scale between 0.5x and 2.5x
                        withAnimation(.spring()) {
                            scale = min(max(newScale, 0.5), 2.5)
                        }
                    }
            )
            .onTapGesture {
                onTap()
            }
            .padding(24)
    }
}

struct ReceiveView: View {
    @StateObject private var vm = ReceiveViewModel()
    @Environment(\.presentationMode) var presentationMode
    @FocusState private var codeFocused: Bool
    
    // UI 状态
    @State private var showControls: Bool = false
    @State private var controlTimer: Timer? = nil

    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.05, blue: 0.12).ignoresSafeArea()

            if vm.isConnected {
                // 观看画面
                ZStack(alignment: .topLeading) {
                    Color.black.ignoresSafeArea()
                        .onTapGesture {
                            toggleControls()
                        }
                    
                    if !vm.videoTracks.isEmpty {
                        let mainTrackIndex = vm.isPiPViewSwapped && vm.videoTracks.count > 1 ? 1 : 0
                        
                        VideoStreamView(track: vm.videoTracks[mainTrackIndex])
                            .ignoresSafeArea()
                            .id(vm.videoTracks[mainTrackIndex].trackId)
                            .onTapGesture {
                                toggleControls()
                            }
                    }
                }

                // 画中画视图 (独立于背景ZStack，直接覆盖在最上层，避免被切掉)
                if vm.videoTracks.count > 1 {
                    let pipTrackIndex = vm.isPiPViewSwapped ? 0 : 1
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            DraggablePiPView(track: vm.videoTracks[pipTrackIndex]) {
                                withAnimation {
                                    vm.swapPiPView()
                                }
                            }
                        }
                    }
                    .padding(.bottom, 60) // 给底部的控制器留出空间
                    // 取消 ignoresSafeArea 确保它留在可视区域内
                }

                // 底部控制面板
                if showControls {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                HStack(spacing: 40) {
                                    // 扬声器控制
                                    Button(action: { 
                                        vm.toggleSpeaker()
                                        resetControlTimer() 
                                    }) {
                                        Image(systemName: vm.isSpeakerEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                            .font(.title2)
                                            .frame(width: 56, height: 56)
                                            .background(vm.isSpeakerEnabled ? Color.white.opacity(0.2) : Color.red.opacity(0.8))
                                            .clipShape(Circle())
                                            .foregroundColor(.white)
                                    }
                                    
                                    // 麦克风控制
                                    Button(action: { 
                                        vm.toggleMic()
                                        resetControlTimer()
                                    }) {
                                        Image(systemName: vm.isMicEnabled ? "mic.fill" : "mic.slash.fill")
                                            .font(.title2)
                                            .frame(width: 56, height: 56)
                                            .background(vm.isMicEnabled ? Color.white.opacity(0.2) : Color.red.opacity(0.8))
                                            .clipShape(Circle())
                                            .foregroundColor(.white)
                                    }
                                    
                                    // 挂断按钮
                                    Button(action: { vm.leave(); presentationMode.wrappedValue.dismiss() }) {
                                        Image(systemName: "phone.down.fill")
                                            .font(.title2)
                                            .frame(width: 56, height: 56)
                                            .background(Color.red)
                                            .clipShape(Circle())
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding(.vertical, 20)
                                .padding(.horizontal, 30)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Capsule())
                                Spacer()
                            }
                            .padding(.bottom, 30)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(1)
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
        .onAppear { 
            codeFocused = true
            showControls = true
            resetControlTimer()
        }
        .onDisappear { if !vm.isConnected { vm.leave() } }
        .onTapGesture { codeFocused = true }
    }
    
    private func toggleControls() {
        withAnimation {
            showControls.toggle()
        }
        if showControls {
            resetControlTimer()
        } else {
            controlTimer?.invalidate()
            controlTimer = nil
        }
    }
    
    private func resetControlTimer() {
        controlTimer?.invalidate()
        controlTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
            withAnimation {
                showControls = false
            }
        }
    }
}

#Preview { ReceiveView() }