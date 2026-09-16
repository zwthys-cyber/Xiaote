import SwiftUI
import TeslaBLEKeyKit

struct VehicleCommandsView: View {
    @State private var vin = ""
    @State private var isConnected = false
    @State private var output: [String] = []
    @State private var vehicle: TeslaVehicle?
    @State private var isLoading = false

    var body: some View {
        List {
            Section("Connection") {
                TextField("Enter VIN", text: $vin)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                Button(isConnected ? "Disconnect" : "Connect") {
                    if isConnected { disconnect() } else { connect() }
                }
                .disabled(vin.isEmpty && !isConnected)
            }

            Section("Commands") {
                commandButton("Wake Vehicle") { try await vehicle?.wakeVehicle() }
                commandButton("Lock") { try await vehicle?.lock() }
                commandButton("Unlock") { try await vehicle?.unlock() }
                commandButton("Open Trunk") { try await vehicle?.openTrunk() }
                commandButton("Close Trunk") { try await vehicle?.closeTrunk() }
                commandButton("Open Frunk") { try await vehicle?.openFrunk() }
                commandButton("Open Tonneau") { try await vehicle?.openTonneau() }
                commandButton("Close Tonneau") { try await vehicle?.closeTonneau() }
                commandButton("Remote Drive") { try await vehicle?.remoteDrive() }
                commandButton("Auto Secure") { try await vehicle?.autoSecureVehicle() }
            }
            .disabled(!isConnected || isLoading)

            if !output.isEmpty {
                Section("Log") {
                    ForEach(Array(output.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                    }
                }
            }
        }
        .navigationTitle("Vehicle Commands")
    }

    private func commandButton(_ title: String, action: @escaping () async throws -> Void) -> some View {
        Button(title) {
            Task { await runCommand(title, action: action) }
        }
    }

    private func connect() {
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                let connection = try BLEConnection(vin: vin)
                let key = TeslaPrivateKey.generate()
                let v = try TeslaVehicle(connector: connection, privateKey: key)
                try await v.connect()
                try await v.startVCSECSession()
                vehicle = v
                isConnected = true
                output.append("[Connected] VIN: \(vin)")
            } catch {
                output.append("[Error] \(error.localizedDescription)")
            }
        }
    }

    private func disconnect() {
        vehicle?.disconnect()
        vehicle = nil
        isConnected = false
        output.append("[Disconnected]")
    }

    @MainActor
    private func runCommand(_ name: String, action: () async throws -> Void) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await action()
            output.append("[OK] \(name)")
        } catch {
            output.append("[Error] \(name): \(error.localizedDescription)")
        }
    }
}
