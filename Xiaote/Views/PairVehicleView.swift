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
                        .font(.system(size: 15 * scale, weight: .semibold))
                        .frame(width: 142 * scale, height: 46 * scale)
                        .foregroundStyle(Color(uiColor: .systemBackground))
                        .background(primaryCapsuleColor, in: Capsule())
                }
                .buttonStyle(PrimaryPressStyle())
                .accessibilityHint("开始搜索附近的 Tesla")

                Button { showingTeslaAccount = true } label: {
                    Text(fleetAccount.isSignedIn ? "Tesla 账号" : "登录 Tesla 账号")
                        .font(.system(size: 14 * scale, weight: .semibold))
                        .frame(width: 142 * scale, height: 44 * scale)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
                        .overlay { Capsule().stroke(.primary, lineWidth: 1.5) }
                }
                .buttonStyle(UtilityPressStyle())
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
                Text("配对列表").font(.system(size: 22 * scale, weight: .bold))
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
        pressFeedback += 1
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
    var body: some View {
        Canvas { context, size in
            let sx = size.width / 430, sy = size.height / 610
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { .init(x: x * sx, y: y * sy) }
            func draw(_ path: Path, _ opacity: Double, _ width: CGFloat) {
                context.stroke(path, with: .color(Color.primary.opacity(opacity)), style: .init(lineWidth: width * sx, lineCap: .round, lineJoin: .round))
            }

            // The body is deliberately wider than the canvas. This lets the
            // full-bleed silhouette continue naturally behind the screen edge.
            var outer = Path()
            outer.move(to: pt(-7, -12))
            outer.addCurve(to: pt(7, 235), control1: pt(-2, 70), control2: pt(2, 170))
            outer.addCurve(to: pt(18, 408), control1: pt(9, 300), control2: pt(10, 360))
            outer.addCurve(to: pt(66, 505), control1: pt(24, 451), control2: pt(39, 484))
            outer.addCurve(to: pt(133, 550), control1: pt(84, 527), control2: pt(105, 541))
            outer.addCurve(to: pt(215, 566), control1: pt(159, 560), control2: pt(189, 565))
            outer.addCurve(to: pt(297, 550), control1: pt(241, 565), control2: pt(271, 560))
            outer.addCurve(to: pt(364, 505), control1: pt(325, 541), control2: pt(346, 527))
            outer.addCurve(to: pt(412, 408), control1: pt(391, 484), control2: pt(406, 451))
            outer.addCurve(to: pt(423, 235), control1: pt(420, 360), control2: pt(421, 300))
            outer.addCurve(to: pt(437, -12), control1: pt(428, 170), control2: pt(432, 70))
            draw(outer, 0.62, 2.2)

            var glass = Path()
            glass.move(to: pt(34, -10))
            glass.addLine(to: pt(22, 210))
            glass.addCurve(to: pt(28, 231), control1: pt(21, 220), control2: pt(23, 227))
            glass.addCurve(to: pt(215, 276), control1: pt(82, 263), control2: pt(145, 276))
            glass.addCurve(to: pt(402, 231), control1: pt(285, 276), control2: pt(348, 263))
            glass.addCurve(to: pt(408, 210), control1: pt(407, 227), control2: pt(409, 220))
            glass.addLine(to: pt(396, -10))
            draw(glass, 0.28, 1.8)

            var cowl = Path()
            cowl.move(to: pt(8, 235))
            cowl.addCurve(to: pt(215, 303), control1: pt(76, 284), control2: pt(145, 303))
            cowl.addCurve(to: pt(422, 235), control1: pt(285, 303), control2: pt(354, 284))
            draw(cowl, 0.28, 1.7)

            var hood = Path()
            hood.move(to: pt(29, 252))
            hood.addCurve(to: pt(72, 457), control1: pt(38, 336), control2: pt(48, 414))
            hood.addCurve(to: pt(126, 514), control1: pt(82, 480), control2: pt(99, 501))
            hood.addCurve(to: pt(215, 538), control1: pt(153, 529), control2: pt(184, 537))
            hood.addCurve(to: pt(304, 514), control1: pt(246, 537), control2: pt(277, 529))
            hood.addCurve(to: pt(358, 457), control1: pt(331, 501), control2: pt(348, 480))
            hood.addCurve(to: pt(401, 252), control1: pt(382, 414), control2: pt(392, 336))
            draw(hood, 0.27, 1.8)

            // Highland blade lamps: a shallow, closed outline that tapers
            // toward the center instead of the swept-back teardrop of the old car.
            var left = Path()
            left.move(to: pt(-4, 421))
            left.addCurve(to: pt(57, 432), control1: pt(16, 422), control2: pt(36, 426))
            left.addCurve(to: pt(132, 452), control1: pt(83, 439), control2: pt(109, 447))
            left.addCurve(to: pt(114, 463), control1: pt(129, 456), control2: pt(123, 460))
            left.addCurve(to: pt(47, 456), control1: pt(88, 461), control2: pt(66, 459))
            left.addCurve(to: pt(-4, 448), control1: pt(29, 453), control2: pt(12, 450))
            left.closeSubpath()
            draw(left, 0.86, 2.7)

            var right = Path()
            right.move(to: pt(434, 421))
            right.addCurve(to: pt(373, 432), control1: pt(414, 422), control2: pt(394, 426))
            right.addCurve(to: pt(298, 452), control1: pt(347, 439), control2: pt(321, 447))
            right.addCurve(to: pt(316, 463), control1: pt(301, 456), control2: pt(307, 460))
            right.addCurve(to: pt(383, 456), control1: pt(342, 461), control2: pt(364, 459))
            right.addCurve(to: pt(434, 448), control1: pt(401, 453), control2: pt(418, 450))
            right.closeSubpath()
            draw(right, 0.86, 2.7)

            // A single restrained lower intake line gives the new front fascia
            // definition without duplicating the outer bumper silhouette.
            var intake = Path()
            intake.move(to: pt(112, 532))
            intake.addCurve(to: pt(215, 551), control1: pt(143, 545), control2: pt(179, 551))
            intake.addCurve(to: pt(318, 532), control1: pt(251, 551), control2: pt(287, 545))
            draw(intake, 0.22, 1.4)
        }
        .drawingGroup()
    }
}
