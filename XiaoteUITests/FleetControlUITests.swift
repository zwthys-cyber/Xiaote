import XCTest

final class FleetControlUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(_ arguments: String...) -> XCUIApplication {
        let app = XCUIApplication()
        let english = arguments.contains("--english")
        app.launchArguments = ["--fleet-ui-tests", "-AppleLanguages", english ? "(en)" : "(zh-Hans)", "-AppleLocale", english ? "en_US" : "zh_CN"] + arguments
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
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "76%")).firstMatch.waitForExistence(timeout: 10))
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
        XCTAssertTrue(app.navigationBars["小特 Model 3"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "76%")).firstMatch.waitForExistence(timeout: 10))
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
        let scroll = app.scrollViews["account-refresh-scroll"]
        let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
        let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        start.press(forDuration: 0.05, thenDragTo: end)
        let refreshing = NSPredicate(format: "value == %@", "正在刷新")
        expectation(for: refreshing, evaluatedWith: scroll)
        waitForExpectations(timeout: 5)
        XCTAssertLessThanOrEqual(app.progressIndicators.count, 1)
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

    func testLocalHomeAndSecuritySettingsAtLargeText() {
        let app = launch("--local-home", "--large-text")
        let options = app.buttons["车辆选项"]
        XCTAssertTrue(options.waitForExistence(timeout: 10))
        capture("local-home-accessibility-text")
        options.tap()
        app.buttons["Face ID 保护"].tap()
        XCTAssertTrue(app.navigationBars["Face ID 保护"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["完成"].isHittable)
        capture("local-security-accessibility-text")
        app.buttons["完成"].tap()
        XCTAssertTrue(options.isHittable)
    }

    func testEnglishRemoteControlsAndForms() {
        let app = launch("--english")
        let lock = app.buttons["remote-quick-door_lock"]
        XCTAssertTrue(lock.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Quick Controls"].exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "76%")).firstMatch.waitForExistence(timeout: 10))
        capture("remote-home-english")
        lock.tap()
        XCTAssertTrue(app.navigationBars["Lock Vehicle"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["remote-send-command"].label.contains("Lock Vehicle"))
        capture("remote-form-english")
    }

    func testPairingAndAccountEntryAtLargeText() {
        let app = launch("--pairing", "--large-text")
        let account = app.buttons["连接 Tesla 账号"]
        XCTAssertTrue(account.waitForExistence(timeout: 10))
        XCTAssertTrue(account.isHittable)
        XCTAssertTrue(app.buttons["正在搜索"].exists)
        XCTAssertFalse(app.buttons["正在搜索"].isEnabled)
        capture("pairing-accessibility-text")
        account.tap()
        XCTAssertTrue(app.navigationBars["小特账号"].waitForExistence(timeout: 5))
        capture("account-sign-in-accessibility-text")
        XCTAssertTrue(app.buttons["完成"].isHittable)
        app.buttons["完成"].tap()
        XCTAssertTrue(account.isHittable)
    }

    func testLocalChargingAndSceneEditorNavigation() {
        let app = launch("--local-home")
        XCTAssertTrue(app.buttons["车辆选项"].waitForExistence(timeout: 10))
        capture("local-home")
        let charging = app.buttons["充电"].firstMatch
        reveal(charging, in: app)
        charging.tap()
        XCTAssertTrue(app.navigationBars["充电"].waitForExistence(timeout: 5))
        capture("local-charging")
        app.navigationBars.buttons.firstMatch.tap()
        let rail = app.scrollViews["车辆功能"]
        let scenes = app.buttons["场景"].firstMatch
        for _ in 0..<4 {
            if scenes.exists && scenes.isHittable { break }
            rail.swipeLeft()
        }
        XCTAssertTrue(scenes.isHittable)
        scenes.tap()
        let add = app.buttons["添加场景"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        capture("local-scenes")
        add.tap()
        XCTAssertTrue(app.textFields["场景名称"].waitForExistence(timeout: 5))
        capture("local-scene-editor")
        app.buttons["取消"].tap()
        XCTAssertTrue(add.isHittable)
    }
}
