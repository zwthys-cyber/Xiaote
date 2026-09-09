import SwiftUI
import VisionKit

struct VINScannerScreen: View {
    let onRecognized: (String) -> Void
    let onCancel: () -> Void
    var previewMode = false
    @State private var failureMessage: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if previewMode {
                LinearGradient(
                    colors: [Color(red: 0.10, green: 0.12, blue: 0.15), .black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            } else {
                VINScannerView(onRecognized: onRecognized) { message in
                    failureMessage = message
                }
                .ignoresSafeArea()
            }

            if let failureMessage {
                unavailable(message: failureMessage)
            } else {
                scannerOverlay
            }
        }
        .preferredColorScheme(.dark)
        .overlay(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 3) {
                Text("扫描 VIN")
                    .font(.headline)
                Text("实时识别 · 不保存相机画面")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 13)
            .padding(.leading, 20)
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .frame(width: 46, height: 46)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .foregroundStyle(.white)
            .accessibilityLabel("取消扫描")
            .padding(.top, 12)
            .padding(.trailing, 18)
        }
    }

    private var scannerOverlay: some View {
        GeometryReader { proxy in
            let scanWidth = min(proxy.size.width - 40, 520)
            let scanHeight = max(96, min(132, proxy.size.height * 0.18))
            ZStack {
                VStack {
                    LinearGradient(colors: [.black.opacity(0.72), .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 180)
                    Spacer()
                    LinearGradient(colors: [.clear, .black.opacity(0.82)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 300)
                }
                .ignoresSafeArea()

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white, lineWidth: 2)
                    .frame(width: scanWidth, height: scanHeight)
                    .shadow(color: .black.opacity(0.5), radius: 8)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Label("对准 17 位 VIN", systemImage: "viewfinder")
                        .font(.headline)
                    Text("请将车机「控制 > 软件」中的完整识别码放入框内")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text("自动过滤汉字与说明文字")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.white.opacity(0.08), in: Capsule())
                        .padding(.top, 4)
                }
                .padding(18)
                .frame(maxWidth: 420)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding(.horizontal, 24)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 36)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("扫描车辆识别码")
        .accessibilityHint("将车机上显示的 17 位 VIN 放入取景框")
    }

    private func unavailable(message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.fill")
                .font(.system(size: 34, weight: .medium))
                .frame(width: 68, height: 68)
                .background(.white.opacity(0.08), in: Circle())
            Text("无法启动 VIN 扫描")
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("返回手动输入", action: onCancel)
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
                .padding(.top, 8)
        }
        .padding(28)
        .frame(maxWidth: 380)
    }
}

struct VINScannerView: UIViewControllerRepresentable {
    let onRecognized: (String) -> Void
    let onFailure: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onRecognized: onRecognized, onFailure: onFailure)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text(textContentType: nil)],
            qualityLevel: .accurate,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: false,
            isHighlightingEnabled: false
        )
        scanner.delegate = context.coordinator
        guard DataScannerViewController.isSupported, DataScannerViewController.isAvailable else {
            DispatchQueue.main.async {
                context.coordinator.onFailure("当前设备或相机状态不支持实时文字扫描，请返回手动输入。")
            }
            return scanner
        }
        do {
            try scanner.startScanning()
        } catch {
            DispatchQueue.main.async {
                context.coordinator.onFailure("请确认已允许相机权限，然后重试。")
            }
        }
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        let bounds = scanner.view.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }
        scanner.regionOfInterest = CGRect(
            x: bounds.width * 0.06,
            y: bounds.height * 0.41,
            width: bounds.width * 0.88,
            height: bounds.height * 0.18
        )
    }

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        uiViewController.stopScanning()
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onRecognized: (String) -> Void
        let onFailure: (String) -> Void
        private var delivered = false

        init(onRecognized: @escaping (String) -> Void, onFailure: @escaping (String) -> Void) {
            self.onRecognized = onRecognized
            self.onFailure = onFailure
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            recognize(items: addedItems, using: dataScanner)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            recognize(items: updatedItems, using: dataScanner)
        }

        private func recognize(items: [RecognizedItem], using dataScanner: DataScannerViewController) {
            guard !delivered else { return }
            for item in items {
                guard case let .text(text) = item else { continue }
                guard let vin = VehicleVIN.scanned(from: text.transcript) else { continue }
                delivered = true
                dataScanner.stopScanning()
                onRecognized(vin)
                return
            }
        }
    }
}
