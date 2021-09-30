@testable import BookPlayer
@testable import BookPlayerKit
import XCTest

class VoiceOverServiceTest: XCTestCase {
    override func setUp() {}

    override func tearDown() {}

    func testRewindText() {
        PlayerManager.rewindInterval = 60

        let localizedString = String(describing: String.localizedStringWithFormat("voiceover_rewind_time".localized, VoiceOverService.secondsToMinutes(PlayerManager.rewindInterval.rounded())))

        XCTAssert(VoiceOverService.rewindText() == localizedString)
    }

    func testForwardText() {
        PlayerManager.forwardInterval = 60

        var localizedString = String(describing: String.localizedStringWithFormat("voiceover_forward_time".localized, VoiceOverService.secondsToMinutes(PlayerManager.forwardInterval.rounded())))

        XCTAssert(VoiceOverService.fastForwardText() == localizedString)

        PlayerManager.forwardInterval = 90

        localizedString = String(describing: String.localizedStringWithFormat("voiceover_forward_time".localized, VoiceOverService.secondsToMinutes(PlayerManager.forwardInterval.rounded())))

        XCTAssert(VoiceOverService.fastForwardText() == localizedString)

        PlayerManager.forwardInterval = 120

        localizedString = String(describing: String.localizedStringWithFormat("voiceover_forward_time".localized, VoiceOverService.secondsToMinutes(PlayerManager.forwardInterval.rounded())))

        XCTAssert(VoiceOverService.fastForwardText() == localizedString)
    }

    func testPerformanceExample() {
        self.measure {}
    }
}
