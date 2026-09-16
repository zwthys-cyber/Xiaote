import SwiftUI
import TeslaBLEKeyKit

struct BLEFramingView: View {
    let chunked: Bool
    @State private var output: [String] = []

    var body: some View {
        List {
            Section {
                Button(chunked ? "Run Chunked Demo" : "Run Encode/Decode Demo") { runDemo() }
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
        .navigationTitle(chunked ? "Chunked Transmission" : "Encode / Decode")
        .onAppear { runDemo() }
    }

    private func runDemo() {
        output.removeAll()
        if chunked {
            runChunkedDemo()
        } else {
            runBasicDemo()
        }
    }

    private func runBasicDemo() {
        do {
            let payload = Data("VCSEC command payload".utf8)
            let framed = try BLEFramer.encode(payload)
            output.append("Payload: \(payload.count) bytes")
            output.append("Framed:  \(framed.count) bytes (2-byte length prefix)")
            output.append("Framed hex: \(framed.hexString())")

            var framer = BLEFramer()
            let decoded = try framer.receive(framed)
            output.append("Decoded: \(decoded.count) message(s)")
            output.append("Match:   \(decoded.first == payload)")
        } catch {
            output.append("Error: \(error.localizedDescription)")
        }
    }

    private func runChunkedDemo() {
        do {
            let payload = Data(repeating: 0xAB, count: 100)
            output.append("Original payload: \(payload.count) bytes")

            let framed = try BLEFramer.encode(payload)
            output.append("Framed total: \(framed.count) bytes")

            let chunkSize = 20
            var chunks: [Data] = []
            var offset = 0
            while offset < framed.count {
                let end = min(offset + chunkSize, framed.count)
                chunks.append(framed[offset..<end])
                offset = end
            }
            output.append("Split into \(chunks.count) chunks (max \(chunkSize) bytes each):")
            for (i, chunk) in chunks.enumerated() {
                output.append("  Chunk \(i): \(chunk.count) bytes")
            }

            var framer = BLEFramer()
            var messages: [Data] = []
            for chunk in chunks {
                let result = try framer.receive(chunk)
                messages.append(contentsOf: result)
            }
            output.append("Reassembled: \(messages.count) message(s)")
            if let first = messages.first {
                output.append("Size match: \(first.count == payload.count)")
                output.append("Data match: \(first == payload)")
            }
        } catch {
            output.append("Error: \(error.localizedDescription)")
        }
    }
}
