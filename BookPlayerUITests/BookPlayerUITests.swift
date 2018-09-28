//
//  BookPlayerUITests.swift
//  BookPlayerUITests
//
//  Created by Gianni Carlo on 9/27/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import XCTest

class BookPlayerUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        app = XCUIApplication()
        app.launch()
    }

    func testSettingsSupport() {
        app.navigationBars["Library"].buttons["Settings"].tap()

        app.tables/*@START_MENU_TOKEN@*/.staticTexts["View project on GitHub"]/*[[".links.staticTexts[\"View project on GitHub\"]",".staticTexts[\"View project on GitHub\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        app/*@START_MENU_TOKEN@*/.otherElements["URL"]/*[[".buttons[\"Address\"]",".otherElements[\"Address\"]",".otherElements[\"URL\"]",".buttons[\"URL\"]"],[[[-1,2],[-1,1],[-1,3,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.tap()
    }

}
