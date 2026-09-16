import SwiftUI
import TeslaBLEKeyKit

struct BLEScannerView: View {
    @State private var advertisements: [VehicleAdvertisement] = []
    @State private var isScanning = false
    @State private var scanTask: Task<Void, Never>?

    var body: some View {
        List {
            Section {
                Button(isScanning ? "Stop Scanning" : "Start Scanning") {
                    if isScanning { stopScan() } else { startScan() }
                }
            }
            if advertisements.isEmpty && isScanning {
                Section {
                    Text("Scanning for nearby Tesla vehicles...")
                        .foregroundStyle(.secondary)
                }
            }
            if !advertisements.isEmpty {
                Section("Discovered Vehicles") {
                    ForEach(advertisements, id: \.localName) { ad in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ad.localName).font(.headline)
                            Text("RSSI: \(ad.rssi) dBm")
                                .font(.caption).foregroundStyle(.secondary)
                            Text("Connectable: \(ad.isConnectable ? "Yes" : "No")")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .onDisappear { stopScan() }
    }

    private func startScan() {
        isScanning = true
        advertisements.removeAll()
        let scanner = BLEScanner()
        scanTask = Task {
            for await ad in scanner.scan() {
                if !advertisements.contains(where: { $0.localName == ad.localName }) {
                    advertisements.append(ad)
                }
            }
        }
    }

    private func stopScan() {
        isScanning = false
        scanTask?.cancel()
        scanTask = nil
    }
}

struct VINToNameView: View {
    @State private var vin = "5YJ3E1EA0LF000000"
    @State private var result = ""

    var body: some View {
        List {
            Section("Input") {
                TextField("Enter VIN", text: $vin)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                Button("Compute BLE Name") { compute() }
            }
            if !result.isEmpty {
                Section("Result") {
                    Text(result)
                        .font(.system(.body, design: .monospaced))
                }
            }
        }
        .onAppear { compute() }
    }

    private func compute() {
        do {
            let name = try vehicleLocalName(forVIN: vin)
            result = "BLE Local Name: \(name)"
        } catch {
            result = "Error: \(error.localizedDescription)"
        }
    }
}
