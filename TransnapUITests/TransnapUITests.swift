//
//  TransnapUITests.swift
//  TransnapUITests
//
//  Created by deepsea on 2026/4/10.
//

import XCTest

final class TransnapUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchesAsMenuBarApp() throws {
        throw XCTSkip(
            "XCUIApplication.launch is not stable for LSUIElement menu bar apps here; smoke coverage lives in TransnapTests.testMenuBarControllerCreatesStatusItemForMenuBarMode."
        )
    }
}
