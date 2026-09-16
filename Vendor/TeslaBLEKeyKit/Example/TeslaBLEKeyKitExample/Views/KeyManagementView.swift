import SwiftUI
import TeslaBLEKeyKit

struct KeyManagementView: View {
    let initialDemo: Int
    @State private var output: [String] = []

    var body: some View {
        List {
            Section("Actions") {
                Button("Generate Key") { runGenerate() }
                Button("Serialize (PEM/DER)") { runSerialize() }
                Button("Restore from Raw") { runRestore() }
                Button("Shared Secret (ECDH)") { runSharedSecret() }
            }
            if !output.isEmpty {
                Section("Output") {
                    ForEach(output, id: \.self) { line in
                        Text(line)
                            .font(.system(.caption, design: .monospaced))
                    }
                }
            }
        }
        .onAppear { runInitialDemo() }
    }

    private func runInitialDemo() {
        switch initialDemo {
        case 0: runGenerate()
        case 1: runSerialize()
        case 2: runRestore()
        case 3: runSharedSecret()
        default: break
        }
    }

    private func runGenerate() {
        output.removeAll()
        let key = TeslaPrivateKey.generate()
        output.append("Private key (raw): \(key.rawRepresentation.count) bytes")
        output.append("Public key (x963): \(key.publicKey.count) bytes")
        output.append("Public key hex: \(key.publicKey.hexString())")
    }

    private func runSerialize() {
        output.removeAll()
        let key = TeslaPrivateKey.generate()
        let pem = key.pemRepresentation
        output.append("PEM:\n\(pem)")
        output.append("DER: \(key.derRepresentation.count) bytes")
        output.append("Raw: \(key.rawRepresentation.count) bytes")
    }

    private func runRestore() {
        output.removeAll()
        let original = TeslaPrivateKey.generate()
        do {
            let restored = try TeslaPrivateKey(rawRepresentation: original.rawRepresentation)
            output.append("Original public key:  \(original.publicKey.hexString())")
            output.append("Restored public key:  \(restored.publicKey.hexString())")
            output.append("Match: \(original.publicKey == restored.publicKey)")
        } catch {
            output.append("Error: \(error.localizedDescription)")
        }
    }

    private func runSharedSecret() {
        output.removeAll()
        let alice = TeslaPrivateKey.generate()
        let bob = TeslaPrivateKey.generate()
        do {
            let secretA = try alice.sharedAESKey(with: bob.publicKey)
            let secretB = try bob.sharedAESKey(with: alice.publicKey)
            output.append("Alice public: \(alice.publicKey.prefix(16).hexString())...")
            output.append("Bob public:   \(bob.publicKey.prefix(16).hexString())...")
            output.append("Shared (A→B): \(secretA.hexString())")
            output.append("Shared (B→A): \(secretB.hexString())")
            output.append("Match: \(secretA == secretB)")
        } catch {
            output.append("Error: \(error.localizedDescription)")
        }
    }
}
