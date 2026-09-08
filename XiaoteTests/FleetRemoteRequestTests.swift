import XCTest
@testable import Xiaote

@MainActor
final class FleetRemoteRequestTests: XCTestCase {
    private func makeAccount() async -> FleetAccountController {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FleetRemoteTestProtocol.self]
        let account = FleetAccountController(api: FleetAPIClient(session: URLSession(configuration: configuration)),
            restoredSession: FleetSession(token: "test-only", expiresAt: .distantFuture), usesKeychain: false)
        await account.refreshVehicles()
        return account
    }

    func testConcurrentRemoteCommandsAreRejectedAndTheSlotIsReleased() async throws {
        let account = await makeAccount()
        let vehicle = try XCTUnwrap(account.vehicles.first)
        let command = try XCTUnwrap(FleetControlForm.commands.first { $0.id == "door_lock" })
        let first = Task { try await account.send(command: command, to: vehicle, payload: Data("{}".utf8)) }
        for _ in 0..<100 {
            if account.remoteCommandInFlight { break }
            await Task.yield()
        }
        XCTAssertTrue(account.remoteCommandInFlight)
        do {
            try await account.send(command: command, to: vehicle, payload: Data("{}".utf8))
            XCTFail("Duplicate command must not be sent")
        } catch { XCTAssertTrue(error.localizedDescription.contains("上一条")) }
        try await first.value
        XCTAssertFalse(account.remoteCommandInFlight)
    }

    func testLogoutInvalidatesAnInFlightCommandReceipt() async throws {
        let account = await makeAccount()
        let vehicle = try XCTUnwrap(account.vehicles.first)
        let command = try XCTUnwrap(FleetControlForm.commands.first { $0.id == "door_lock" })
        let first = Task { try await account.send(command: command, to: vehicle, payload: Data("{}".utf8)) }
        for _ in 0..<100 {
            if account.remoteCommandInFlight { break }
            await Task.yield()
        }
        XCTAssertTrue(account.remoteCommandInFlight)
        await account.signOut()
        do { try await first.value; XCTFail("A previous session must not publish a success receipt") }
        catch is CancellationError { }
        XCTAssertFalse(account.isSignedIn)
        XCTAssertFalse(account.remoteCommandInFlight)
    }

    func testVehicleRefusalIsNotReportedAsSuccess() async throws {
        let account = await makeAccount()
        let vehicle = try XCTUnwrap(account.vehicles.first)
        let command = try XCTUnwrap(FleetControlForm.commands.first { $0.id == "charge_start" })
        do {
            try await account.send(command: command, to: vehicle, payload: Data("{}".utf8))
            XCTFail("Vehicle refused the command")
        } catch { XCTAssertTrue(error.localizedDescription.contains("充电线")) }
        XCTAssertFalse(account.remoteCommandInFlight)
    }

    func testTelemetryFromAnotherVehicleIsRejected() async throws {
        let account = await makeAccount()
        let vehicle = try XCTUnwrap(account.vehicles.first)
        let control = FleetRemoteController(account: account, vehicle: vehicle)
        await control.refresh()
        XCTAssertNil(control.data)
        XCTAssertNil(control.updatedAt)
        XCTAssertTrue(control.message?.contains("不匹配") == true)
    }
}

private final class FleetRemoteTestProtocol: URLProtocol {
    private var pending: DispatchWorkItem?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let path = request.url!.path
        let body: String
        var status = 200
        if path == "/v1/vehicles" { body = #"{"response":[{"id":1,"vin":"LRW3E7FA9MC123456","state":"online"}]}"# }
        else if path.hasSuffix("/commands/door_lock") { body = #"{"response":{"result":true}}"# }
        else if path.hasSuffix("/commands/charge_start") { body = #"{"response":{"result":false,"reason":"车辆未连接充电线"}}"# }
        else if path.hasSuffix("/data") { body = #"{"response":{"vin":"LRW3E7FA9MC654321","charge_state":{"battery_level":50}}}"# }
        else if request.httpMethod == "DELETE" { body = "{}" }
        else { status = 404; body = #"{"error":{"message":"Unsupported optional test endpoint"}}"# }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: Data(body.utf8))
            self.client?.urlProtocolDidFinishLoading(self)
        }
        pending = item
        DispatchQueue.main.asyncAfter(deadline: .now() + (path.contains("/commands/") ? 0.3 : 0.01), execute: item)
    }
    override func stopLoading() { pending?.cancel() }
}
