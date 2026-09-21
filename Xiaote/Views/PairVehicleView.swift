import SwiftUI
import UIKit

struct PairVehicleView: View {
    @Environment(VehicleController.self) private var vehicle
    @Environment(FleetAccountController.self) private var fleetAccount
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    var showsCloseButton = false
    var automaticallyScans = true

    @State private var scanner = NearbyTeslaScanner()
    @State private var mode: Mode = .welcome
    @State private var scanTask: Task<Void, Never>?
    @State private var pressFeedback = 0
    @State private var showingTeslaAccount = false
    @State private var loginError: String?
    @State private var isStartingLogin = false
    @State private var scanStartedAt = Date()

    private enum Mode: Equatable { case welcome, scanning, finished }

    private var primaryCapsuleColor: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? .white : UIColor(red: 0.19, green: 0.20, blue: 0.24, alpha: 1)
        })
    }

    var body: some View {
        GeometryReader { proxy in
            let scale = min(max(proxy.size.width / 430, 0.88), 1.2)
            ZStack(alignment: .top) {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                vehicleArtwork(scale: scale)
                if mode == .welcome {
                    welcomeContent(scale: scale, bottomInset: proxy.safeAreaInsets.bottom)
                        .transition(.opacity)
                } else {
                    pairingContent(scale: scale, bottomInset: proxy.safeAreaInsets.bottom)
                        .transition(.opacity)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .sensoryFeedback(.warning, trigger: pressFeedback)
        .fullScreenCover(isPresented: $showingTeslaAccount) {
            TeslaAccountView().environment(fleetAccount)
        }
        .alert("Tesla 登录失败", isPresented: Binding(
            get: { loginError != nil },
            set: { if !$0 { loginError = nil } }
        )) {
            Button("确定", role: .cancel) { loginError = nil }
        } message: {
            Text(loginError ?? "请稍后重试")
        }
        .onDisappear { scanTask?.cancel(); scanner.stop() }
        .edgeSwipeToDismiss(enabled: showsCloseButton)
    }

    private func vehicleArtwork(scale: CGFloat) -> some View {
        TeslaPairingArtwork()
            .frame(height: 610 * scale)
            .offset(y: mode == .welcome ? 0 : -272 * scale)
            .animation(reduceMotion ? AppMotion.reduced : .spring(response: 0.48, dampingFraction: 0.76), value: mode)
            .accessibilityHidden(true)
    }

    private func welcomeContent(scale: CGFloat, bottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 626 * scale)
            Text("小特钥匙")
                .font(.system(size: 25.5 * scale, weight: .bold, design: .rounded))
                .tracking(-0.8)
            Text("靠近车辆自动连接以解锁爱车和使用车控")
                .font(.system(size: 11.5 * scale, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 13 * scale)
            VStack(spacing: 14 * scale) {
                Button {
                    beginScanning()
                } label: {
                    Text("配对车辆")
                        .font(.system(size: 14.5 * scale, weight: .semibold))
                        .frame(width: 142 * scale, height: 40 * scale)
                        .foregroundStyle(Color(uiColor: .systemBackground))
                        .background(primaryCapsuleColor, in: Capsule())
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PrimaryPressStyle())
                .accessibilityHint("开始搜索附近的 Tesla")

                Button {
                    pressFeedback += 1
                    if fleetAccount.isSignedIn && !fleetAccount.needsReauthentication {
                        showingTeslaAccount = true
                    } else {
                        guard !isStartingLogin, !fleetAccount.isWorking else { return }
                        isStartingLogin = true
                        Task { @MainActor in
                            defer { isStartingLogin = false }
                            await fleetAccount.signIn()
                            if let error = fleetAccount.errorMessage {
                                loginError = error
                            } else if fleetAccount.isSignedIn && !fleetAccount.needsReauthentication {
                                showingTeslaAccount = true
                            }
                        }
                    }
                } label: {
                    Text(isStartingLogin ? "正在登录…" : (fleetAccount.isSignedIn ? "Tesla 账号" : "登录 Tesla 账号"))
                        .font(.system(size: 13.5 * scale, weight: .semibold))
                        .frame(width: 142 * scale, height: 38 * scale)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
                        .overlay { Capsule().stroke(.primary, lineWidth: 1.5) }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(UtilityPressStyle())
                .disabled(isStartingLogin || fleetAccount.isWorking)
            }
            .padding(.top, 32 * scale)
            Spacer(minLength: max(18, bottomInset))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func pairingContent(scale: CGFloat, bottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 294 * scale)
            HStack {
                Text("配对列表").font(.system(size: 20 * scale, weight: .bold))
                Spacer()
                Button {
                    pressFeedback += 1
                    closePairing()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15 * scale, weight: .medium))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(UtilityPressStyle())
                .accessibilityLabel("关闭配对列表")
            }
            Text("配对期间请保持屏幕常亮；如连接失败，请暂时关闭其他 Tesla 钥匙 App\n如有多个手机钥匙，请暂时关闭其他手机蓝牙")
                .font(.system(size: 12.5 * scale, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Group {
                if isPairing {
                    pairingProgress(scale: scale)
                } else if !scanner.vehicles.isEmpty {
                    vehicleList(scale: scale)
                } else if mode == .scanning {
                    PairingSearchLoader(startedAt: scanStartedAt)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityLabel("正在搜索 Tesla 车辆")
                } else {
                    Text(scanner.bluetoothMessage ?? "未找到特斯拉车辆")
                        .font(.system(size: 14.5 * scale, weight: .medium))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(.bottom, max(16, bottomInset))
        }
        .padding(.horizontal, 24 * scale)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func vehicleList(scale: CGFloat) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(scanner.vehicles) { candidate in
                    Button {
                        scanner.stop(); scanTask?.cancel()
                        Task { await vehicle.pair(with: candidate) }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "car.side.fill").font(.system(size: 19, weight: .medium))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(candidate.modelName ?? "Tesla · \(candidate.shortIdentifier)")
                                    .font(.system(size: 15 * scale, weight: .semibold))
                                Text("\(candidate.signalLabel) · \(candidate.distanceLabel)")
                                    .font(.system(size: 12 * scale)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                        }
                        .padding(16).frame(maxWidth: .infinity)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(UtilityPressStyle())
                }
            }
            .padding(.top, 22)
        }
        .scrollIndicators(.hidden)
    }

    private func pairingProgress(scale: CGFloat) -> some View {
        VStack(spacing: 18) {
            if vehicle.phase == .pairingAwaitingCard {
                Image(systemName: "key.card.fill")
                    .font(.system(size: 32 * scale, weight: .medium))
                Text("在车辆中控屏确认添加手机钥匙")
                    .font(.system(size: 17 * scale, weight: .semibold))
                Text("按车机提示刷钥匙卡，确认看到新钥匙后继续")
                    .font(.system(size: 14 * scale))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    Task { await vehicle.confirmPairingAndConnect() }
                } label: {
                    Text(vehicle.canConfirmPairing ? "已在车机确认，继续" : "等待车机授权")
                        .font(.system(size: 16 * scale, weight: .semibold))
                        .frame(maxWidth: 280, minHeight: 54)
                        .background(.primary, in: Capsule())
                        .foregroundStyle(Color(uiColor: .systemBackground))
                }
                .buttonStyle(PrimaryPressStyle())
                .disabled(!vehicle.canConfirmPairing)
                .opacity(vehicle.canConfirmPairing ? 1 : 0.42)
            } else {
                ProgressView().controlSize(.regular).tint(.primary)
                Text(vehicle.phase == .connecting ? "正在连接车辆" : "正在建立安全连接")
                    .font(.system(size: 16 * scale, weight: .medium))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var isPairing: Bool {
        switch vehicle.phase {
        case .connecting, .pairingAwaitingCard, .handshaking: true
        default: false
        }
    }

    private func beginScanning() {
        pressFeedback += 1
        scanStartedAt = Date()
        withAnimation(reduceMotion ? AppMotion.reduced : .spring(response: 0.48, dampingFraction: 0.76)) { mode = .scanning }
        guard automaticallyScans else { return }
        scanner.start()
        scanTask?.cancel()
        scanTask = Task { @MainActor in
            do { try await Task.sleep(for: .seconds(6)) } catch { return }
            scanner.stop()
            withAnimation(.easeOut(duration: 0.2)) { mode = .finished }
        }
    }

    private func closePairing() {
        scanTask?.cancel(); scanner.stop()
        withAnimation(reduceMotion ? AppMotion.reduced : .spring(response: 0.48, dampingFraction: 0.76)) { mode = .welcome }
        if showsCloseButton { dismiss() }
    }

}

private struct TeslaPairingArtwork: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Image("HighlandPairing")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(colorScheme == .dark
                ? Color(red: 131 / 255, green: 135 / 255, blue: 145 / 255)
                : Color(red: 116 / 255, green: 119 / 255, blue: 125 / 255))
    }
}


/// Native adaptation of Beautiful UI's MIT-licensed Loading State (Drive).
/// Attribution: Resources/BeautifulUI-LICENSE.txt.
private struct PairingSearchLoader: View {
    let startedAt: Date
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 30,
                                paused: scenePhase != .active)) { timeline in
            let elapsed = max(0, timeline.date.timeIntervalSince(startedAt))
            HStack(spacing: 10) {
                Canvas { context, _ in
                    for index in 0..<9 {
                        let row = index / 3
                        let column = index % 3
                        let delay = Double(column + abs(row - 1)) * 0.09
                        let phase = max(0, elapsed - delay).truncatingRemainder(dividingBy: 0.65) / 0.65
                        let brightness = reduceMotion ? 0.65 : 0.15 + 0.85 * pow(sin(phase * .pi), 2)
                        let rect = CGRect(x: Double(column) * 5.5, y: Double(row) * 5.5, width: 4, height: 4)
                        context.fill(Path(roundedRect: rect, cornerRadius: 1),
                                     with: .color(.primary.opacity(brightness)))
                    }
                }
                .frame(width: 15, height: 15)
                Text("正在搜索")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .overlay {
                        if !reduceMotion {
                            GeometryReader { proxy in
                                let phase = elapsed.truncatingRemainder(dividingBy: 1.4) / 1.4
                                LinearGradient(colors: [.clear, .primary.opacity(0.85), .clear],
                                               startPoint: .leading, endPoint: .trailing)
                                    .frame(width: proxy.size.width * 0.65)
                                    .offset(x: proxy.size.width * (phase * 1.65 - 0.65))
                            }
                            .mask(Text("正在搜索").font(.system(size: 13, weight: .medium)))
                        }
                    }
                Text(String(format: "%.1f s", elapsed))
                    .font(.system(size: 12, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 42, alignment: .leading)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("正在搜索 Tesla 车辆")
        .accessibilityIdentifier("pairing-search-loader")
    }
}
