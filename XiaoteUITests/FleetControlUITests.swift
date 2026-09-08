import XCTest

final class FleetControlUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(_ arguments: String...) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--fleet-ui-tests", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"] + arguments
        app.launch()
        return app
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }

    func testHomeAndCommandReceiptWithoutOptimisticStateChange() {
        let app = launch()
        let lock = app.buttons["remote-quick-door_lock"]
        XCTAssertTrue(lock.waitForExistence(timeout: 10))
        let loading = app.otherElements["remote-initial-loading"]
        if loading.exists { XCTAssertTrue(loading.waitForNonExistence(timeout: 10)) }
        capture("remote-home")
        lock.tap()
        let send = app.buttons["remote-send-command"]
        XCTAssertTrue(send.waitForExistence(timeout: 5))
        capture("remote-lock-confirmation")
        send.tap()
        XCTAssertFalse(send.isEnabled)
        let result = app.descendants(matching: .any)["remote-command-result"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 8))
        XCTAssertFalse(send.isEnabled, "An accepted command must not be sent twice")
        capture("remote-command-accepted")
    }

    func testCategoriesAndNativeParameterForms() {
        let app = launch()
        XCTAssertTrue(app.buttons["remote-quick-door_lock"].waitForExistence(timeout: 10))
        let climate = app.buttons["remote-category-座舱与空调"]
        reveal(climate, in: app)
        capture("remote-categories")
        climate.tap()
        let temperature = app.buttons["remote-command-set_temps"]
        XCTAssertTrue(temperature.waitForExistence(timeout: 5))
        temperature.tap()
        XCTAssertTrue(app.steppers["remote-field-driver_temp"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.steppers["remote-field-passenger_temp"].exists)
        capture("remote-temperature-form")
    }

    func testFailedCommandShowsVehicleReasonAndAllowsExplicitRetry() {
        let app = launch("--command-failure")
        XCTAssertTrue(app.buttons["remote-quick-door_lock"].waitForExistence(timeout: 10))
        app.buttons["remote-quick-door_lock"].tap()
        let send = app.buttons["remote-send-command"]
        XCTAssertTrue(send.waitForExistence(timeout: 5))
        send.tap()
        let result = app.descendants(matching: .any)["remote-command-result"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 8))
        XCTAssertTrue(send.isEnabled)
        capture("remote-command-rejected")
    }

    func testLargeTextKeepsControlsReachable() {
        let app = launch("--large-text")
        let lock = app.buttons["remote-quick-door_lock"]
        XCTAssertTrue(lock.waitForExistence(timeout: 10))
        capture("remote-home-accessibility-text")
        reveal(lock, in: app)
        XCTAssertGreaterThanOrEqual(lock.frame.height, 44)
        capture("remote-controls-accessibility-text")
        lock.tap()
        let send = app.buttons["remote-send-command"]
        reveal(send, in: app)
        XCTAssertGreaterThanOrEqual(send.frame.height, 44)
        capture("remote-form-accessibility-text")
    }

    func testEmptyAccountPullRefreshHasOnlyOneIndicator() {
        let app = launch("--empty-account")
        XCTAssertTrue(app.buttons["重新同步"].waitForExistence(timeout: 15))
        let scroll = app.scrollViews.firstMatch
        let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
        let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        start.press(forDuration: 0.05, thenDragTo: end)
        let refresh = app.descendants(matching: .any)["pull-refresh-indicator"].firstMatch
        XCTAssertTrue(refresh.waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["正在同步车辆"].exists)
        XCTAssertTrue(app.buttons["重新同步"].exists)
        capture("account-single-pull-refresh")
    }

    func testUnavailableDataShowsRecoveryInsteadOfFakeValues() {
        let app = launch("--data-failure")
        let message = app.descendants(matching: .any)["remote-status-message"].firstMatch
        XCTAssertTrue(message.waitForExistence(timeout: 12))
        XCTAssertTrue(app.buttons["唤醒车辆"].exists)
        capture("remote-vehicle-unavailable")
    }
}
