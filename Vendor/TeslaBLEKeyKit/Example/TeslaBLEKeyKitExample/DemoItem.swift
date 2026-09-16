import Foundation

enum DemoSection: Int, CaseIterable {
    case keyManagement
    case ble
    case crypto
    case bleFraming
    case vehicleConfig
    case vehicleCommands
    case pairingAndStatus

    var title: String {
        switch self {
        case .keyManagement: return "Key Management"
        case .ble: return "BLE"
        case .crypto: return "Crypto"
        case .bleFraming: return "BLE Framing"
        case .vehicleConfig: return "Vehicle Configuration"
        case .vehicleCommands: return "Vehicle Commands"
        case .pairingAndStatus: return "Pairing & Status"
        }
    }

    var items: [DemoItem] {
        switch self {
        case .keyManagement:
            return [
                DemoItem(title: "Generate Key", subtitle: "Create a new P-256 private key"),
                DemoItem(title: "Serialize Key", subtitle: "Export to PEM / DER / Raw formats"),
                DemoItem(title: "Restore Key", subtitle: "Import key from raw bytes round-trip"),
                DemoItem(title: "Shared Secret", subtitle: "ECDH shared AES key derivation"),
            ]
        case .ble:
            return [
                DemoItem(title: "Scan for Vehicles", subtitle: "Discover nearby Tesla vehicles via BLE"),
                DemoItem(title: "VIN to BLE Name", subtitle: "Compute BLE local name from VIN"),
            ]
        case .crypto:
            return [
                DemoItem(title: "AES-GCM (12-byte nonce)", subtitle: "Standard nonce encrypt/decrypt"),
                DemoItem(title: "AES-GCM (4-byte Tesla)", subtitle: "Tesla BLE 4-byte nonce mode"),
            ]
        case .bleFraming:
            return [
                DemoItem(title: "Encode / Decode", subtitle: "Frame a message with 2-byte length prefix"),
                DemoItem(title: "Chunked Transmission", subtitle: "Fragment and reassemble large payloads"),
            ]
        case .vehicleConfig:
            return [
                DemoItem(title: "Configuration Presets", subtitle: "Standard vs Four-Byte Nonce BLE"),
            ]
        case .vehicleCommands:
            return [
                DemoItem(title: "Vehicle Commands", subtitle: "Lock, Unlock, Trunk, Frunk, Wake..."),
            ]
        case .pairingAndStatus:
            return [
                DemoItem(title: "Pairing & Status", subtitle: "Request pairing and query vehicle status"),
            ]
        }
    }
}

struct DemoItem {
    let title: String
    let subtitle: String
}
