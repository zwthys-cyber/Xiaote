import Testing
import Foundation
@testable import TeslaBLEKeyKit

// MARK: - VCSEC Session Cache Restore Tests

@Suite("VCSEC session restore")
struct VCSECSessionRestoreTests {
    private func makeMessage() -> UniversalMessage_RoutableMessage {
        var message = UniversalMessage_RoutableMessage()
        message.toDestination.domain = .vehicleSecurity
        message.protobufMessageAsBytes = Data([0x01, 0x02, 0x03])
        return message
    }

    @Test("Export carries the current counter and restore continues monotonically")
    func restoreContinuesCounter() throws {
        let key = TeslaPrivateKey.generate()
        let peer = TeslaPrivateKey.generate()
        var info = Signatures_SessionInfo()
        info.publicKey = peer.publicKey
        info.counter = 10
        info.epoch = Data([0xAA, 0xBB])
        info.clockTime = 100
        let session = try TeslaSession(
            privateKey: key,
            verifierName: Data("LRW3E7FA9MC123456".utf8),
            verifierInfo: info,
            nonceMode: .standard12Byte
        )

        var first = makeMessage()
        try session.authorize(message: &first, method: .gcm, expiresIn: 5)
        let firstCounter = first.signatureData.aesGcmPersonalizedData.counter
        #expect(firstCounter == 11)

        let exported = try session.exportSessionInfo()
        #expect(try Signatures_SessionInfo(serializedBytes: exported).counter == 11)

        // A session restored from the export must never reuse the last
        // counter: the vehicle rejects replays.
        let restored = try TeslaSession(
            privateKey: key,
            verifierName: Data("LRW3E7FA9MC123456".utf8),
            verifierInfo: try Signatures_SessionInfo(serializedBytes: exported),
            nonceMode: .standard12Byte
        )
        var second = makeMessage()
        try restored.authorize(message: &second, method: .gcm, expiresIn: 5)
        #expect(second.signatureData.aesGcmPersonalizedData.counter == firstCounter + 1)
    }

    @Test("DomainSessionState accepts an export and re-exports it")
    func domainStateRestoreRoundTrip() throws {
        let key = TeslaPrivateKey.generate()
        let peer = TeslaPrivateKey.generate()
        var info = Signatures_SessionInfo()
        info.publicKey = peer.publicKey
        info.counter = 7
        info.epoch = Data([0x01])
        info.clockTime = 50
        let original = try TeslaSession(
            privateKey: key,
            verifierName: Data("LRW3E7FA9MC123456".utf8),
            verifierInfo: info,
            nonceMode: .standard12Byte
        )
        let exported = try original.exportSessionInfo()

        let state = DomainSessionState(
            privateKey: key,
            vin: "LRW3E7FA9MC123456",
            nonceMode: .standard12Byte
        )
        try state.restore(from: exported)
        let reexported = try #require(state.export())
        #expect(try Signatures_SessionInfo(serializedBytes: reexported).counter == 7)
    }
}
