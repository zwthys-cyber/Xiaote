import SwiftUI
import TeslaBLEKeyKit

struct CryptoDemoView: View {
    let useTeslaNonce: Bool
    @State private var plaintext = "unlock_doors"
    @State private var output: [String] = []

    var body: some View {
        List {
            Section("Input") {
                TextField("Plaintext", text: $plaintext)
                Button("Encrypt & Decrypt") { runDemo() }
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
        .navigationTitle(useTeslaNonce ? "AES-GCM (4-byte)" : "AES-GCM (12-byte)")
        .onAppear { runDemo() }
    }

    private func runDemo() {
        output.removeAll()
        do {
            let alice = TeslaPrivateKey.generate()
            let bob = TeslaPrivateKey.generate()
            let sessionKey = try alice.sharedAESKey(with: bob.publicKey)
            output.append("Session key: \(sessionKey.hexString())")

            let gcm = try VariableNonceAESGCM(key: sessionKey)
            let message = Data(plaintext.utf8)
            let nonceMode: AESGCMNonceMode = useTeslaNonce ? .teslaBLE4Byte : .standard12Byte
            let sealed = try gcm.seal(plaintext: message, nonceMode: nonceMode)

            output.append("Nonce mode: \(useTeslaNonce ? "4-byte Tesla" : "12-byte standard")")
            output.append("Plaintext:  \(plaintext)")
            output.append("Ciphertext: \(sealed.ciphertext.hexString())")
            output.append("Nonce:      \(sealed.nonce.hexString())")
            output.append("Tag:        \(sealed.tag.hexString())")

            let decrypted = try gcm.open(sealed)
            let decryptedStr = String(data: decrypted, encoding: .utf8) ?? "<binary>"
            output.append("Decrypted:  \(decryptedStr)")
            output.append("Match:      \(decrypted == message)")
        } catch {
            output.append("Error: \(error.localizedDescription)")
        }
    }
}
