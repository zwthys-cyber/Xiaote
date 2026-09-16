import XCTest
@testable import Xiaote

final class PassiveKeyChallengeTests: XCTestCase {
    func testRecognizesAuthenticationRequestWithTwentyByteToken() {
        let token = Data(repeating: 0x5A, count: 20)
        let sessionInfo = LegacyVCSECClient.messageField(1, token)
        let request = LegacyVCSECClient.messageField(2, sessionInfo)
        let challenge = LegacyVCSECClient.messageField(3, request)
        XCTAssertTrue(LegacyVCSECClient.isAuthenticationRequest(challenge))
    }

    func testRejectsMalformedAuthenticationRequest() {
        // AuthenticationRequest without session info.
        XCTAssertFalse(LegacyVCSECClient.isAuthenticationRequest(
            LegacyVCSECClient.messageField(3, Data())))
        // Token shorter than the 20-byte session token.
        let shortToken = Data(repeating: 0x5A, count: 19)
        let shortSession = LegacyVCSECClient.messageField(1, shortToken)
        let shortRequest = LegacyVCSECClient.messageField(2, shortSession)
        XCTAssertFalse(LegacyVCSECClient.isAuthenticationRequest(
            LegacyVCSECClient.messageField(3, shortRequest)))
        // Session data is not a challenge.
        XCTAssertFalse(LegacyVCSECClient.isAuthenticationRequest(
            LegacyVCSECClient.messageField(2, Data())))
        // Empty payload.
        XCTAssertFalse(LegacyVCSECClient.isAuthenticationRequest(Data()))
    }
}
