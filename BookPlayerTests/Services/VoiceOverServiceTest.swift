import XCTest
@testable import BookPlayer

class VoiceOverServiceTest: XCTestCase {

    override func setUp() {
    }

    override func tearDown() {
    }

    func testRewindText() {
        let intervals: [Double] = [60.0, 90.0, 120.0]
        let conversionTexts = [
            "Rewind 1 minute ",
            "Rewind 1 minute 30 seconds",
            "Rewind 2 minutes "
        ]

        intervals.enumerated().forEach { (offset, element) in
            PlayerManager.shared.rewindInterval = element
            XCTAssert(VoiceOverService.rewindText() == conversionTexts[offset])
        }
    }

    func testForwardText() {
        let intervals: [Double] = [60.0, 90.0, 120.0]
        let conversionTexts = [
            "Fast Forward 1 minute ",
            "Fast Forward 1 minute 30 seconds",
            "Fast Forward 2 minutes "
        ]

        intervals.enumerated().forEach { (offset, element) in
            PlayerManager.shared.forwardInterval = element
            XCTAssert(VoiceOverService.fastForwardText() == conversionTexts[offset])
        }
    }

    func testPerformanceExample() {
        self.measure {
        }
    }
}
