import SwiftUI
import UIKit

struct PairVehicleView: View {
    @Environment(VehicleController.self) private var vehicle
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    var showsCloseButton = false
    var automaticallyScans = true

    @State private var scanner = NearbyTeslaScanner()
    @State private var mode: Mode = .welcome
    @State private var showingPairingNotice = false
    @State private var scanTask: Task<Void, Never>?
    @State private var pressFeedback = 0

    private enum Mode: Equatable { case welcome, scanning, finished }

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
        .alert("请先关闭其他 Tesla 钥匙相关 App\n含 Tesla 原生 App", isPresented: $showingPairingNotice) {
            Button("取消", role: .cancel) {}
            Button("确定", role: .destructive) { beginScanning() }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: pressFeedback)
        .onDisappear { scanTask?.cancel(); scanner.stop() }
        .edgeSwipeToDismiss(enabled: showsCloseButton)
    }

    private func vehicleArtwork(scale: CGFloat) -> some View {
        TeslaPairingArtwork()
            .frame(height: 610 * scale)
            .offset(y: mode == .welcome ? 0 : -292 * scale)
            .animation(reduceMotion ? AppMotion.reduced : .spring(response: 0.48, dampingFraction: 0.76), value: mode)
            .accessibilityHidden(true)
    }

    private func welcomeContent(scale: CGFloat, bottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 626 * scale)
            Text("小特钥匙")
                .font(.system(size: 30 * scale, weight: .bold, design: .rounded))
                .tracking(-1.2)
            Text("靠近车辆自动连接以解锁爱车和使用车控")
                .font(.system(size: 13 * scale, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 15 * scale)
            VStack(spacing: 18 * scale) {
                Button {
                    pressFeedback += 1
                    showingPairingNotice = true
                } label: {
                    Text("配对车辆")
                        .font(.system(size: 17 * scale, weight: .semibold))
                        .frame(width: 150 * scale, height: 56 * scale)
                        .foregroundStyle(Color(uiColor: .systemBackground))
                        .background(.primary, in: Capsule())
                }
                .buttonStyle(PrimaryPressStyle())
                .accessibilityHint("开始搜索附近的 Tesla")

                Button(action: openShortcuts) {
                    Text("添加 Siri")
                        .font(.system(size: 17 * scale, weight: .semibold))
                        .frame(width: 150 * scale, height: 54 * scale)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
                        .overlay { Capsule().stroke(.primary, lineWidth: 2) }
                }
                .buttonStyle(UtilityPressStyle())
            }
            .padding(.top, 39 * scale)
            Spacer(minLength: max(18, bottomInset))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func pairingContent(scale: CGFloat, bottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 294 * scale)
            HStack {
                Text("配对列表").font(.system(size: 22 * scale, weight: .bold))
                Spacer()
                Button(action: closePairing) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18 * scale, weight: .medium))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(UtilityPressStyle())
                .accessibilityLabel("关闭配对列表")
            }
            Text("保持屏幕常亮，并确认关闭 Tesla 原生 App 后台\n如有配对多个手机，请暂时关闭其他手机蓝牙")
                .font(.system(size: 14 * scale, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Group {
                if isPairing {
                    pairingProgress(scale: scale)
                } else if !scanner.vehicles.isEmpty {
                    vehicleList(scale: scale)
                } else if mode == .scanning {
                    ProgressView().controlSize(.regular).tint(.primary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityLabel("正在搜索 Tesla 车辆")
                } else {
                    Text(scanner.bluetoothMessage ?? "未找到特斯拉车辆")
                        .font(.system(size: 16 * scale, weight: .medium))
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
                                    .font(.system(size: 16 * scale, weight: .semibold))
                                Text("\(candidate.signalLabel) · \(candidate.distanceLabel)")
                                    .font(.system(size: 13 * scale)).foregroundStyle(.secondary)
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

    private func openShortcuts() {
        guard let url = URL(string: "shortcuts://gallery") else { return }
        UIApplication.shared.open(url)
    }
}

private struct TeslaPairingArtwork: View {
    var body: some View {
        Canvas { context, size in
            let sx = size.width / 430, sy = size.height / 610
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { .init(x: x * sx, y: y * sy) }
            func draw(_ path: Path, _ opacity: Double, _ width: CGFloat) {
                context.stroke(path, with: .color(Color.primary.opacity(opacity)), style: .init(lineWidth: width * sx, lineCap: .round, lineJoin: .round))
            }
            var outer = Path()
            outer.move(to: pt(-6, -12)); outer.addCurve(to: pt(7, 235), control1: pt(-1, 62), control2: pt(2, 168))
            outer.addCurve(to: pt(24, 430), control1: pt(9, 308), control2: pt(12, 377)); outer.addCurve(to: pt(102, 555), control1: pt(37, 486), control2: pt(61, 531))
            outer.addCurve(to: pt(215, 586), control1: pt(139, 576), control2: pt(179, 586)); outer.addCurve(to: pt(328, 555), control1: pt(251, 586), control2: pt(291, 576))
            outer.addCurve(to: pt(406, 430), control1: pt(369, 531), control2: pt(393, 486)); outer.addCurve(to: pt(423, 235), control1: pt(418, 377), control2: pt(421, 308))
            outer.addCurve(to: pt(436, -12), control1: pt(428, 168), control2: pt(431, 62)); draw(outer, 0.62, 2.1)

            var glass = Path()
            glass.move(to: pt(34, -10)); glass.addLine(to: pt(21, 211)); glass.addCurve(to: pt(25, 230), control1: pt(20, 220), control2: pt(21, 225))
            glass.addCurve(to: pt(215, 275), control1: pt(83, 266), control2: pt(147, 275)); glass.addCurve(to: pt(405, 230), control1: pt(283, 275), control2: pt(347, 266))
            glass.addCurve(to: pt(409, 211), control1: pt(409, 225), control2: pt(410, 220)); glass.addLine(to: pt(396, -10)); draw(glass, 0.32, 2)

            var bonnet = Path()
            bonnet.move(to: pt(7, 234)); bonnet.addCurve(to: pt(215, 305), control1: pt(76, 287), control2: pt(144, 305)); bonnet.addCurve(to: pt(423, 234), control1: pt(286, 305), control2: pt(354, 287)); draw(bonnet, 0.31, 1.8)

            var hood = Path()
            hood.move(to: pt(30, 252)); hood.addCurve(to: pt(93, 520), control1: pt(39, 340), control2: pt(54, 465)); hood.addCurve(to: pt(215, 558), control1: pt(119, 548), control2: pt(166, 556))
            hood.addCurve(to: pt(337, 520), control1: pt(264, 556), control2: pt(311, 548)); hood.addCurve(to: pt(400, 252), control1: pt(376, 465), control2: pt(391, 340)); draw(hood, 0.30, 1.8)

            var left = Path()
            left.move(to: pt(-5, 408)); left.addCurve(to: pt(83, 531), control1: pt(23, 449), control2: pt(41, 479)); left.addCurve(to: pt(-4, 486), control1: pt(91, 540), control2: pt(29, 510)); draw(left, 0.82, 3.1)
            var right = Path()
            right.move(to: pt(435, 408)); right.addCurve(to: pt(347, 531), control1: pt(407, 449), control2: pt(389, 479)); right.addCurve(to: pt(434, 486), control1: pt(339, 540), control2: pt(401, 510)); draw(right, 0.82, 3.1)
            var bumper = Path()
            bumper.move(to: pt(-8, 478)); bumper.addCurve(to: pt(215, 585), control1: pt(55, 545), control2: pt(133, 585)); bumper.addCurve(to: pt(438, 478), control1: pt(297, 585), control2: pt(375, 545)); draw(bumper, 0.82, 3.2)
        }
        .drawingGroup()
    }
}
