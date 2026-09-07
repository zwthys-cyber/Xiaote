import XCTest
@testable import Xiaote

final class ExperienceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000)
    private func request(id: UUID = UUID(), vehicleID: String = "vehicle-a", command: WatchVehicleCommand = .lock) -> WatchCommandRequest {
        WatchCommandRequest(id: id, vehicleID: vehicleID, command: command, issuedAt: now)
    }

    func testWatchRequestRunsOnceEvenAfterLedgerReload() throws {
        let request = request()
        var ledger = WatchCommandLedger()
        XCTAssertNotNil(ledger.accept(request, now: now))
        let data = try JSONEncoder().encode(ledger)
        var restored = try JSONDecoder().decode(WatchCommandLedger.self, from: data)
        restored.recoverInterruptedCommands()
        XCTAssertNil(restored.accept(request, now: now.addingTimeInterval(1)))
        XCTAssertEqual(restored.previousResult(for: request)?.status, .unconfirmed)
    }

    func testRequestIDCannotBeReusedForAnotherCarOrAction() {
        let first = request()
        var ledger = WatchCommandLedger()
        XCTAssertNotNil(ledger.accept(first, now: now))
        let otherCar = request(id: first.id, vehicleID: "vehicle-b")
        XCTAssertNil(ledger.previousResult(for: otherCar))
        XCTAssertNil(ledger.accept(otherCar, now: now))
        XCTAssertNil(ledger.accept(request(id: first.id, command: .unlock), now: now))
    }

    func testExpiredAndFutureWatchRequestsAreRejected() {
        let request = request()
        var ledger = WatchCommandLedger()
        XCTAssertNil(ledger.accept(request, now: now.addingTimeInterval(90)))
        XCTAssertNil(ledger.accept(request, now: now.addingTimeInterval(-10)))
    }

    func testLateAcknowledgementCannotOverwriteSuccess() {
        let request = request()
        var tracking = WatchCommandTracking()
        tracking.begin(request)
        tracking.receive(WatchCommandResult(request: request, status: .succeeded, message: "Done"))
        tracking.receive(WatchCommandResult(request: request, status: .accepted, message: "Accepted"))
        tracking.markUnconfirmed()
        XCTAssertEqual(tracking.result?.status, .succeeded)
        XCTAssertFalse(tracking.isPending)
    }

    func testRestoredWatchRequestCannotAppearUnderAnotherVehicle() throws {
        var tracking = WatchCommandTracking()
        let previous = request()
        tracking.begin(previous)
        let encoded = try JSONEncoder().encode(tracking)
        var restored = try JSONDecoder().decode(WatchCommandTracking.self, from: encoded)
        restored.markUnconfirmed()
        restored.selectVehicle("vehicle-b")
        restored.receive(WatchCommandResult(request: previous, status: .succeeded, message: "Old car locked"))
        XCTAssertNil(restored.request)
        XCTAssertNil(restored.result)
        XCTAssertFalse(restored.isPending)
    }

    func testTimeoutCanRecoverButCannotReplaceNewerCommand() {
        let first = request()
        var tracking = WatchCommandTracking()
        tracking.begin(first)
        tracking.markUnconfirmed()
        tracking.receive(WatchCommandResult(request: first, status: .succeeded, message: "Done"))
        XCTAssertEqual(tracking.result?.status, .succeeded)
        let second = request()
        tracking.begin(second)
        tracking.receive(WatchCommandResult(request: first, status: .failed, message: "Old error"))
        XCTAssertTrue(tracking.isPending)
        XCTAssertNil(tracking.result)
    }

    func testFailureStopsOnlyRemainingSceneSteps() {
        var execution = SceneExecution(id: UUID(), sceneID: UUID(), name: "回家", vehicleID: "car", titles: ["锁车", "空调", "哨兵"])
        execution.update(0, status: .confirmed)
        execution.update(1, status: .failed("连接中断"))
        execution.finish(reason: "场景已停止")
        XCTAssertEqual(execution.steps[0].status, .confirmed)
        XCTAssertEqual(execution.steps[1].status, .failed("连接中断"))
        XCTAssertEqual(execution.steps[2].status, .skipped("未执行后续操作"))
        execution.update(2, status: .confirmed)
        XCTAssertEqual(execution.steps[2].status, .skipped("未执行后续操作"))
    }

    func testInterruptedRunningStepIsUncertainRatherThanUnsent() {
        var execution = SceneExecution(id: UUID(), sceneID: UUID(), name: "测试", vehicleID: "car", titles: ["锁车", "空调"])
        execution.update(0, status: .running)
        execution.finish(reason: "切车")
        XCTAssertEqual(execution.steps[0].status, .uncertain)
        XCTAssertEqual(execution.steps[1].status, .skipped("未执行后续操作"))
        XCTAssertFalse(execution.isRunning)
    }

    func testUnconfirmedSceneIsNotPresentedAsFullyConfirmed() {
        var execution = SceneExecution(id: UUID(), sceneID: UUID(), name: "测试", vehicleID: "car", titles: ["锁车"])
        execution.update(0, status: .sent)
        execution.finish()
        XCTAssertEqual(execution.summary, "指令已发送，部分状态待确认")
    }

    func testFreshnessExpiresWithoutReceivingAnotherSnapshot() {
        XCTAssertTrue(VehicleDataAge.isFresh(now, at: now.addingTimeInterval(30)))
        XCTAssertFalse(VehicleDataAge.isFresh(now, at: now.addingTimeInterval(121)))
        XCTAssertFalse(VehicleDataAge.isFresh(nil, at: now))
        XCTAssertFalse(VehicleDataAge.isFresh(now.addingTimeInterval(10), at: now))
    }

    func testCategoryReadDoesNotRefreshMissingBatteryField() {
        var freshness = VehicleStateFreshness()
        freshness.record(.battery, at: now)
        freshness.record(.charge, at: now.addingTimeInterval(200))
        XCTAssertFalse(VehicleDataAge.isFresh(freshness.dates[.battery], at: now.addingTimeInterval(200)))
    }
}
