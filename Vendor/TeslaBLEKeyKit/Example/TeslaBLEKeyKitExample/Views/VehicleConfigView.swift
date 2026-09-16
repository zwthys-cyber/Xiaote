import SwiftUI
import TeslaBLEKeyKit

struct VehicleConfigView: View {
    var body: some View {
        List {
            Section("Standard") {
                configRow(config: .standard, name: "Standard")
            }
            Section("Four-Byte Nonce BLE") {
                configRow(config: .fourByteNonceBLE, name: "Four-Byte Nonce BLE")
            }
        }
        .navigationTitle("Configuration Presets")
    }

    private func configRow(config: TeslaVehicleConfiguration, name: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent("Name", value: name)
            LabeledContent("Nonce Length", value: "\(config.nonceMode.length) bytes")
            LabeledContent("Command Timeout", value: "\(Int(config.commandTimeout))s")
            LabeledContent("Session Timeout", value: "\(Int(config.sessionTimeout))s")
        }
        .font(.system(.body, design: .monospaced))
    }
}
