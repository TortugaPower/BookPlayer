@testable import BookPlayer
import XCTest

class VoiceOverServiceTest: XCTestCase {
    override func setUp() {}

    override func tearDown() {}

    func testRewindText() {
        PlayerManager.shared.rewindInterval = 60
        XCTAssert(VoiceOverService.rewindText() == "Rewind 1 minute")
    }

    func testForwardText() {
        PlayerManager.shared.forwardInterval = 60
        XCTAssert(VoiceOverService.fastForwardText() == "Fast Forward 1 minute")

        PlayerManager.shared.forwardInterval = 90
        XCTAssert(VoiceOverService.fastForwardText() == "Fast Forward 1 minute 30 seconds")

        PlayerManager.shared.forwardInterval = 120
        XCTAssert(VoiceOverService.fastForwardText() == "Fast Forward 2 minutes")
    }

    func testSecondsToMinutes() {
        XCTAssert(VoiceOverService.secondsToMinutes(7952) == "2 hours 12 minutes 32 seconds")
        XCTAssert(VoiceOverService.secondsToMinutes(3661) == "1 hour 1 minute 1 second")
    }

    func testPerformanceExample() {
        self.measure {}
    }
}
