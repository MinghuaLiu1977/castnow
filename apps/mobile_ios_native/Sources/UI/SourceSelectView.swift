import SwiftUI
import AVFoundation

struct SourceSelectView: View {
    @State private var shareScreen = true
    @State private var shareCamera = false
    @State private var shareMic = true
    @State private var navigateToBroadcast = false
    @State private var isLaunching = false
    @State private var permissionError: String?
    @State private var showError = false
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ZStack {
            kBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶栏返回
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

                if let ui = UIImage(named: "CastNowSplashIcon") {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(.top, 12)
                } else {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 36))
                        .foregroundColor(kPrimary)
                        .padding(.top, 12)
                }

                Text(L10n.sourceTitle)
                    .font(.system(size: 22, weight: .black))
                    .tracking(2)
                    .foregroundColor(.white)
                    .padding(.top, 12)

                Text(L10n.sourceDesc)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.top, 6)

                VStack(spacing: 10) {
                    sourceCard(icon: "iphone", title: L10n.sourceScreen, subtitle: L10n.sourceScreenSub, isOn: $shareScreen, exclusive: true) {
                        shareCamera = false
                    }
                    sourceCard(icon: "video.fill", title: L10n.sourceCamera, subtitle: L10n.sourceCameraSub, isOn: $shareCamera, exclusive: true) {
                        shareScreen = false
                    }
                    sourceCard(icon: "mic.fill", title: L10n.sourceMic, subtitle: L10n.sourceMicSub, isOn: $shareMic, exclusive: false) {}
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                Spacer()

                Button(action: launch) {
                    HStack(spacing: 12) {
                        if isLaunching {
                            ProgressView().tint(.white)
                        } else {
                            Text(L10n.sourceLaunch)
                                .font(.system(size: 16, weight: .black))
                                .tracking(1.5)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 20, weight: .bold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: 320)
                    .padding(.vertical, 22)
                    .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(kPrimary))
                }
                .disabled(!shareScreen && !shareCamera || isLaunching)
                .opacity(shareScreen || shareCamera ? 1 : 0.4)
                .padding(.bottom, 32)
                .alert(L10n.sourceLaunchFailed, isPresented: $showError) {
                    Button(L10n.alertOK, role: .cancel) {}
                } message: {
                    Text(permissionError ?? "")
                }
            }

            NavigationLink(destination: BroadcastView(shareScreen: shareScreen, shareCamera: shareCamera, shareMic: shareMic), isActive: $navigateToBroadcast) { EmptyView() }
        }
        .navigationBarHidden(true)
    }

    private func launch() {
        isLaunching = true
        Task {
            var granted = true
            var deniedParts: [String] = []

            // Only request camera permission if user selected camera
            if shareCamera {
                let camOk = await AVCaptureDevice.requestAccess(for: .video)
                if !camOk { granted = false; deniedParts.append(L10n.permCamera) }
            }

            // Only request mic permission if user selected mic
            if shareMic {
                let micOk = await AVCaptureDevice.requestAccess(for: .audio)
                if !micOk { granted = false; deniedParts.append(L10n.permMic) }
            }

            // Screen-only: no camera/mic permission needed (ReplayKit handles its own)

            await MainActor.run {
                isLaunching = false
                if granted {
                    navigateToBroadcast = true
                } else {
                    permissionError = String(format: L10n.permDeniedFormat,
                                             deniedParts.joined(separator: L10n.permJoin))
                    showError = true
                }
            }
        }
    }

    private func sourceCard(icon: String, title: String, subtitle: String, isOn: Binding<Bool>, exclusive: Bool, extra: @escaping () -> Void) -> some View {
        Button(action: {
            if exclusive {
                isOn.wrappedValue.toggle()
                if isOn.wrappedValue { extra() }
            } else {
                isOn.wrappedValue.toggle()
            }
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundColor(isOn.wrappedValue ? kPrimary : .white.opacity(0.4))
                    .frame(width: 50, height: 50)
                    .background(RoundedRectangle(cornerRadius: 16).fill(isOn.wrappedValue ? kPrimary.opacity(0.1) : Color.white.opacity(0.05)))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(isOn.wrappedValue ? .white : .white.opacity(0.4))
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(isOn.wrappedValue ? .white.opacity(0.7) : .white.opacity(0.3))
                }
                Spacer()
                RoundedRectangle(cornerRadius: 6)
                    .fill(isOn.wrappedValue ? kPrimary : Color.clear)
                    .frame(width: 24, height: 24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isOn.wrappedValue ? kPrimary : Color.white.opacity(0.3), lineWidth: 2)
                    )
                    .overlay(
                        isOn.wrappedValue ? Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundColor(kBackground) : nil
                    )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(isOn.wrappedValue ? Color.white.opacity(0.08) : Color.white.opacity(0.02)))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(isOn.wrappedValue ? kPrimary.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1))
        }
    }
}

#Preview { SourceSelectView() }