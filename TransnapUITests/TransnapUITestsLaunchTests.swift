//
//  TransnapUITestsLaunchTests.swift
//  TransnapUITests
//
//  Created by deepsea on 2026/4/10.
//

import XCTest

final class TransnapUITestsLaunchTests: XCTestCase {
    @MainActor
    func testLaunchScreenSmokeIsCoveredByMenuBarUITest() throws {
        throw XCTSkip("Transnap is a menu bar app without a launch screen; smoke coverage lives in TransnapUITests.")
    }
}
