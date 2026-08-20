//
//  WorkStampUITests.swift
//  WorkStampUITests
//
//  Created by Codex on 2026/7/1.
//

import XCTest

final class WorkStampUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCameraShellExposesCaptureAndSettingsControls() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        let captureButton = app.buttons["camera.captureButton"]
        let settingsButton = app.buttons["camera.settingsButton"]

        XCTAssertTrue(captureButton.waitForExistence(timeout: 5))
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))

        settingsButton.tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 5))
    }
}
