//
//  TranscriptFeatureUITests.swift
//  BookPlayerTests
//
//  Created for synchronized text viewer feature testing.
//

import SwiftUI
import XCTest
@testable import BookPlayer

/// UI-level sanity checks for the transcript view
final class TranscriptFeatureUITests: XCTestCase {

    func testTranscriptViewRendersWithActiveIndex() {
        let view = TranscriptView(
            lines: [
                TranscriptLine(time: 0, text: "Line one"),
                TranscriptLine(time: 5, text: "Line two"),
                TranscriptLine(time: 10, text: "Line three")
            ],
            activeIndex: 1,
            onLineTap: { _ in },
            scrollRequest: 0
        )
        .environmentObject(ThemeViewModel())

        let controller = UIHostingController(rootView: view)
        XCTAssertNotNil(controller.view)
    }

    func testTranscriptViewRendersWithNoActiveIndex() {
        let view = TranscriptView(
            lines: [
                TranscriptLine(time: 0, text: "Line one"),
                TranscriptLine(time: 5, text: "Line two")
            ],
            activeIndex: nil,
            onLineTap: { _ in },
            scrollRequest: 0
        )
        .environmentObject(ThemeViewModel())

        let controller = UIHostingController(rootView: view)
        XCTAssertNotNil(controller.view)
    }
}
