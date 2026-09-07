import XCTest
import TeslaBLEKeyKit
@testable import Xiaote

final class ReliabilityTests: XCTestCase {
    func testAuthenticationReservationRejectsASecondCommand() throws {
        var admission = CommandAdmission()
        let first = try XCTUnwrap(admission.reserve())
        XCTAssertNil(admission.reserve(), "Authentication must already own the command slot")
        admission.finish(first)
        XCTAssertNotNil(admission.reserve())
    }

    func testOldAuthenticationCannotReleaseNewVehicleCommand() throws {
        var admission = CommandAdmission()
        let old = try XCTUnwrap(admission.reserve())
        admission.invalidate()
        let current = try XCTUnwrap(admission.reserve())
        XCTAssertFalse(admission.owns(old))
        admission.finish(old)
        XCTAssertTrue(admission.owns(current))
        XCTAssertNil(admission.reserve())
    }

    func testPartialRefreshDoesNotMakeOldLockDataFresh() {
        var freshness = VehicleStateFreshness()
        let old = Date(timeIntervalSince1970: 100)
        let recent = Date(timeIntervalSince1970: 200)
        for category in [VehicleStateFreshness.Category.basic, .charge, .climate, .closures] {
            freshness.record(category, at: old)
        }
        freshness.record(.charge, at: recent)
        freshness.record(.media, at: recent)
        XCTAssertEqual(freshness.updatedAt(requiring: [.basic, .charge, .climate, .closures]), old)
        XCTAssertEqual(freshness.dates[.charge], recent)
    }

    func testMissingCategoryNeverReceivesSyntheticTimestamp() {
        var freshness = VehicleStateFreshness()
        freshness.record(.basic)
        XCTAssertNil(freshness.updatedAt(requiring: [.basic, .charge]))
    }

    func testNormalChargingStopsDoNotTriggerPowerAlerts() {
        for condition in [ChargingCondition.stopped, .complete, .disconnected, .starting, .charging, .unknown] {
            XCTAssertFalse(condition.hasPowerIssue)
        }
        XCTAssertTrue(ChargingCondition.noPower.hasPowerIssue)
    }

    @MainActor
    func testPartialClosuresCannotConfirmAllDoorsClosed() {
        XCTAssertNil(VehicleController.confirmedOpenCount([false, nil, false, nil]))
        XCTAssertEqual(VehicleController.confirmedOpenCount([false, false, false, false]), 0)
        XCTAssertEqual(VehicleController.confirmedOpenCount([true, nil, false, nil]), 1)
    }

    func testTemporaryServerFailureDoesNotRequireLogin() {
        XCTAssertFalse(FleetAPIError.http(status: 503, code: "tesla_temporarily_unavailable", message: "Retry").requiresReauthentication)
        XCTAssertTrue(FleetAPIError.http(status: 401, code: "invalid_session", message: "Expired").requiresReauthentication)
    }

    func testHTTPStatusAndErrorCodeSurviveDecoding() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ExpiredSessionURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let api = FleetAPIClient(session: session)
        do {
            _ = try await api.vehicles(token: "test-session")
            XCTFail("Expected an authorization error")
        } catch let FleetAPIError.http(status, code, _) {
            XCTAssertEqual(status, 401)
            XCTAssertEqual(code, "invalid_session")
        }
    }
}

private final class ExpiredSessionURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil,
                                       headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(#"{"error":{"code":"invalid_session","message":"Expired"}}"#.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
