import SwiftUI
import TeslaBLEKeyKit

struct PairingStatusView: View {
    @State private var vin = ""
    @State private var output: [String] = []
    @State private var isLoading = false

    var body: some View {
        List {
            Section("Connection") {
                TextField("Enter VIN", text: $vin)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
            }

            Section("Actions") {
                Button("Request Pairing") {
                    Task { await requestPairing() }
                }
                .disabled(vin.isEmpty || isLoading)

                Button("Query Vehicle Status") {
                    Task { await queryStatus() }
                }
                .disabled(vin.isEmpty || isLoading)
            }

            if !output.isEmpty {
                Section("Output") {
                    ForEach(Array(output.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                    }
                }
            }
        }
        .navigationTitle("Pairing & Status")
    }

    @MainActor
    private func requestPairing() async {
        isLoading = true
        defer { isLoading = false }
        output.removeAll()
        do {
            let connection = try BLEConnection(vin: vin)
            try await connection.connect(timeout: 10)
            let pairing = TeslaPairing(connector: connection)
            let key = TeslaPrivateKey.generate()
            try await pairing.requestPairing(
                publicKey: key.publicKey,
                role: .owner,
                formFactor: .iosDevice
            )
            output.append("[OK] Pairing request sent")
            output.append("Public key: \(key.publicKey.hexString())")
            connection.close()
        } catch {
            output.append("[Error] \(error.localizedDescription)")
        }
    }

    @MainActor
    private func queryStatus() async {
        isLoading = true
        defer { isLoading = false }
        output.removeAll()
        do {
            let connection = try BLEConnection(vin: vin)
            try await connection.connect(timeout: 10)
            let pairing = TeslaPairing(connector: connection)
            let status = try await pairing.vehicleStatus()
            output.append("[OK] Vehicle status received")
            output.append("Status: \(status)")
            connection.close()
        } catch {
            output.append("[Error] \(error.localizedDescription)")
        }
    }
}
