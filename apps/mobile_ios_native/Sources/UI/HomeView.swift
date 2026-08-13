import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationView {
            ZStack {
                kBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // ── 品牌区 ──
                        VStack(spacing: 0) {
                            if let ui = UIImage(named: "AppIconImage") {
                            Image(uiImage: ui)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        } else {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(kPrimary.opacity(0.15))
                                .frame(width: 80, height: 80)
                                .overlay(Image(systemName: "bolt.fill").font(.system(size: 40)).foregroundColor(kPrimary))
                        }

                            Text("即刻投屏")
                                .font(.system(size: 32, weight: .black))
                                .foregroundColor(.white)
                                .padding(.top, 20)

                            // 接收端访问胶囊
                            HStack(spacing: 8) {
                                Image(systemName: "globe")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(kPrimary)
                                Text("接收端访问: ")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.7))
                                Text("castnow.padap.cn")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(kPrimary)
                                    .underline()
                                    .onTapGesture { openURL("https://castnow.padap.cn") }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                            )
                            .padding(.top, 20)
                        }
                        .padding(.top, 24)

                        // ── 动作按钮 ──
                        VStack(spacing: 16) {
                            NavigationLink(destination: SourceSelectView()) {
                                actionCard(
                                    title: "开始投屏",
                                    subtitle: "共享摄像头或屏幕",
                                    icon: "dot.radiowaves.left.and.right",
                                    primary: true
                                )
                            }
                            NavigationLink(destination: ReceiveView()) {
                                actionCard(
                                    title: "接收投屏",
                                    subtitle: "观看投屏内容",
                                    icon: "arrow.down.circle.fill",
                                    primary: false
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 40)

                        // ── 底部 ──
                        VStack(spacing: 12) {
                            Text("CastNow P2P 引擎 v3.1.5")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(2)
                                .foregroundColor(.white.opacity(0.15))

                            HStack(spacing: 0) {
                                footerLink("条款") { openURL("https://castnow.padap.cn/terms.html") }
                                footerSeparator()
                                footerLink("隐私") { openURL("https://castnow.padap.cn/privacy.html") }
                                footerSeparator()
                                footerLink("帮助") { openURL("mailto:mingh.liu@gmail.com") }
                            }
                        }
                        .padding(.top, 48)
                        .padding(.bottom, 32)
                    }
                    .frame(maxWidth: 500)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
    }

    private func actionCard(title: String, subtitle: String, icon: String, primary: Bool) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(primary ? Color.black : kPrimary)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundColor(primary ? Color.black : kTextPrimary)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(primary ? Color.black.opacity(0.65) : Color.white.opacity(0.5))
            }
            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(primary ? kPrimary : kSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(primary ? 0 : 0.12), lineWidth: 1)
        )
    }

    private func footerLink(_ text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.horizontal, 10)
    }

    private func footerSeparator() -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(width: 1, height: 10)
    }

    private func openURL(_ string: String) {
        guard let url = URL(string: string) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview { HomeView() }