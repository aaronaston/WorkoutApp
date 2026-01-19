import XCTest

final class SettingsTogglePersistenceUITests: XCTestCase {
    func testSettingsTogglesPersistAcrossRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["ui-testing-reset"]
        app.launch()

        app.tabBars.buttons["Settings"].tap()

        let calendarToggle = app.switches["settings.calendarSyncToggle"]
        XCTAssertTrue(calendarToggle.waitForExistence(timeout: 5))
        calendarToggle.tap()

        let healthKitToggle = app.switches["settings.healthKitSyncToggle"]
        XCTAssertTrue(healthKitToggle.waitForExistence(timeout: 5))
        healthKitToggle.tap()

        app.terminate()

        let relaunchedApp = XCUIApplication()
        relaunchedApp.launch()
        relaunchedApp.tabBars.buttons["Settings"].tap()

        let calendarValue = relaunchedApp.switches["settings.calendarSyncToggle"].value as? String
        let healthKitValue = relaunchedApp.switches["settings.healthKitSyncToggle"].value as? String
        XCTAssertEqual(calendarValue, "1")
        XCTAssertEqual(healthKitValue, "0")
    }
}
