//
//  TranscriptViewerViewModelTests.swift
//  BookPlayerTests
//
//  Created for synchronized text viewer feature testing.
//

import Foundation
import XCTest
@testable import BookPlayer
@testable import BookPlayerKit

/// Tests for transcript highlighting behavior in the player view model
@MainActor
final class TranscriptViewerViewModelTests: XCTestCase {

    private var viewModel: PlayerViewModel!
    private var playerManager: PlayerManager!

    override func setUp() {
        super.setUp()
        let libraryService = LibraryService()
        let playbackService = PlaybackService()
        playbackService.setup(libraryService: libraryService)
        let syncService = SyncService()

        playerManager = PlayerManager(
            libraryService: LibraryServiceProtocolMock(),
            playbackService: PlaybackServiceProtocolMock(),
            syncService: SyncServiceProtocolMock(),
            speedService: SpeedServiceProtocolMock(),
            shakeMotionService: ShakeMotionServiceProtocolMock(),
            widgetReloadService: WidgetReloadService()
        )

        viewModel = PlayerViewModel(
            libraryService: libraryService,
            playbackService: playbackService,
            playerManager: playerManager,
            syncService: syncService
        )
    }

    override func tearDown() {
        viewModel = nil
        playerManager = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialState() {
        XCTAssertTrue(viewModel.transcriptLines.isEmpty)
        XCTAssertFalse(viewModel.hasTranscript)
        XCTAssertNil(viewModel.activeTranscriptIndex)
        XCTAssertFalse(viewModel.isShowingTranscript)
        XCTAssertEqual(viewModel.transcriptScrollRequest, 0)
    }

    // MARK: - Update Current Time Tests

    func testRefreshTranscriptPositionWithoutLines() {
        viewModel.refreshTranscriptPosition()

        XCTAssertNil(viewModel.activeTranscriptIndex)
        XCTAssertEqual(viewModel.transcriptScrollRequest, 1)
    }

    func testRefreshTranscriptPositionUpdatesIndex() {
        viewModel.transcriptLines = [
            TranscriptLine(time: 10.0, text: "First line"),
            TranscriptLine(time: 20.0, text: "Second line"),
            TranscriptLine(time: 30.0, text: "Third line")
        ]

        let item = PlayableItem.mock
        item.currentTime = 15.0
        playerManager.currentItem = item

        viewModel.refreshTranscriptPosition()
        XCTAssertEqual(viewModel.activeTranscriptIndex, 0)

        item.currentTime = 25.0
        viewModel.refreshTranscriptPosition()
        XCTAssertEqual(viewModel.activeTranscriptIndex, 1)

        item.currentTime = 5.0
        viewModel.refreshTranscriptPosition()
        XCTAssertNil(viewModel.activeTranscriptIndex)
    }

    func testHandleSliderUpEventUpdatesActiveIndexAndScroll() {
        UserDefaults.sharedDefaults.set(false, forKey: Constants.UserDefaults.chapterContextEnabled)
        viewModel.transcriptLines = [
            TranscriptLine(time: 10.0, text: "First line"),
            TranscriptLine(time: 20.0, text: "Second line"),
            TranscriptLine(time: 60.0, text: "Third line")
        ]
        viewModel.isShowingTranscript = true

        let item = PlayableItem.mock
        item.currentTime = 0
        playerManager.currentItem = item

        let initialScroll = viewModel.transcriptScrollRequest
        viewModel.handleSliderUpEvent(with: 0.5)

        XCTAssertEqual(viewModel.activeTranscriptIndex, 1)
        XCTAssertEqual(
            viewModel.transcriptScrollRequest,
            initialScroll + 1,
            "Expected a single scroll request when scrubbing, got \(viewModel.transcriptScrollRequest - initialScroll)."
        )
    }

    func testSeekToTranscriptTimeUpdatesActiveIndexAndScroll() {
        viewModel.transcriptLines = [
            TranscriptLine(time: 5.0, text: "Line 1"),
            TranscriptLine(time: 15.0, text: "Line 2"),
            TranscriptLine(time: 25.0, text: "Line 3")
        ]
        viewModel.isShowingTranscript = true

        let initialScroll = viewModel.transcriptScrollRequest
        viewModel.seekToTranscriptTime(18.0)

        XCTAssertEqual(viewModel.activeTranscriptIndex, 1)
        XCTAssertEqual(
            viewModel.transcriptScrollRequest,
            initialScroll + 1,
            "Expected a single scroll request when seeking, got \(viewModel.transcriptScrollRequest - initialScroll)."
        )
    }

    func testRefreshTranscriptPositionIncrementsScrollOnHighlightChange() {
        viewModel.transcriptLines = [
            TranscriptLine(time: 10.0, text: "First line"),
            TranscriptLine(time: 20.0, text: "Second line"),
            TranscriptLine(time: 30.0, text: "Third line")
        ]
        viewModel.isShowingTranscript = true

        let item = PlayableItem.mock
        item.currentTime = 12.0
        playerManager.currentItem = item

        viewModel.refreshTranscriptPosition()
        let scrollAfterFirst = viewModel.transcriptScrollRequest
        XCTAssertEqual(viewModel.activeTranscriptIndex, 0)

        item.currentTime = 22.0
        viewModel.refreshTranscriptPosition()
        XCTAssertEqual(viewModel.activeTranscriptIndex, 1)
        XCTAssertEqual(
            viewModel.transcriptScrollRequest,
            scrollAfterFirst + 1,
            "Expected a single scroll request on highlight change, got \(viewModel.transcriptScrollRequest - scrollAfterFirst)."
        )
    }
}
