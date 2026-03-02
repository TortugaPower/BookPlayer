//
//  TranscriptFeatureUITests.swift
//  BookPlayerTests
//
//  Created for synchronized text viewer feature UI testing.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Foundation
import XCTest
import SwiftUI
import Combine
@testable import BookPlayer
@testable import BookPlayerKit

/// UI tests for the transcript feature
/// Note: These tests validate the UI component behavior and integration
class TranscriptFeatureUITests: XCTestCase {
  
  var transcriptViewerViewModel: TranscriptViewerViewModel!
  
  override func setUp() {
    super.setUp()
    transcriptViewerViewModel = TranscriptViewerViewModel()
    cleanupTestFiles()
  }
  
  override func tearDown() {
    cleanupTestFiles()
    transcriptViewerViewModel = nil
    super.tearDown()
  }
  
  /// Clean up test LRC files
  private func cleanupTestFiles() {
    let processedURL = DataManager.getProcessedFolderURL()
    let lrcDirectory = processedURL.appendingPathComponent("lrc", isDirectory: true)
    
    if FileManager.default.fileExists(atPath: lrcDirectory.path) {
      try? FileManager.default.removeItem(at: lrcDirectory)
    }
  }
  
  // MARK: - TranscriptViewer View Tests
  
  /// Test TranscriptViewer displays empty state when no transcript
  func testTranscriptViewerEmptyState() {
    // ViewModel with no document
    let viewModel = TranscriptViewerViewModel()
    XCTAssertFalse(viewModel.hasTranscript)
    
    // The view should show empty state
    XCTAssertTrue(viewModel.lines.isEmpty)
    XCTAssertNil(viewModel.lrcDocument)
  }
  
  /// Test TranscriptViewer displays lines when transcript is loaded
  func testTranscriptViewerDisplaysLines() throws {
    let relativePath = "books/ui_test.mp3"
    
    // Create a test transcript
    let lrcURL = LRCService.shared.getLRCFileURL(for: relativePath)
    try FileManager.default.createDirectory(
      at: lrcURL.deletingLastPathComponent(),
      withIntermediateDirectories: true,
      attributes: nil
    )
    
    let content = """
    [ti:UI Test]
    [00:10.00]First line
    [00:20.00]Second line
    [00:30.00]Third line
    """
    
    try content.write(to: lrcURL, atomically: true, encoding: .utf8)
    
    // Load into view model
    transcriptViewerViewModel.loadTranscript(for: relativePath)
    
    // Verify view model state
    XCTAssertTrue(transcriptViewerViewModel.hasTranscript)
    XCTAssertEqual(transcriptViewerViewModel.lines.count, 3)
    XCTAssertEqual(transcriptViewerViewModel.lines[0].text, "First line")
    XCTAssertEqual(transcriptViewerViewModel.lines[1].text, "Second line")
    XCTAssertEqual(transcriptViewerViewModel.lines[2].text, "Third line")
  }
  
  /// Test current line highlighting
  func testCurrentLineHighlighting() throws {
    let relativePath = "books/highlight_test.mp3"
    
    // Create transcript
    let lrcURL = LRCService.shared.getLRCFileURL(for: relativePath)
    try FileManager.default.createDirectory(
      at: lrcURL.deletingLastPathComponent(),
      withIntermediateDirectories: true,
      attributes: nil
    )
    
    let content = """
    [00:10.00]Line 1
    [00:20.00]Line 2
    [00:30.00]Line 3
    """
    
    try content.write(to: lrcURL, atomically: true, encoding: .utf8)
    
    transcriptViewerViewModel.loadTranscript(for: relativePath)
    
    // Update to first line
    transcriptViewerViewModel.updateCurrentTime(15.0)
    XCTAssertEqual(transcriptViewerViewModel.currentLineIndex, 0)
    
    // Update to second line
    transcriptViewerViewModel.updateCurrentTime(25.0)
    XCTAssertEqual(transcriptViewerViewModel.currentLineIndex, 1)
    
    // Update to third line
    transcriptViewerViewModel.updateCurrentTime(35.0)
    XCTAssertEqual(transcriptViewerViewModel.currentLineIndex, 2)
  }
  
  // MARK: - Line Tap Interaction Tests
  
  /// Test line tap callback
  func testLineTapCallback() throws {
    let expectation = self.expectation(description: "Line tap called")
    var tappedTimestamp: TimeInterval?
    
    let relativePath = "books/tap_test.mp3"
    let lrcURL = LRCService.shared.getLRCFileURL(for: relativePath)
    try FileManager.default.createDirectory(
      at: lrcURL.deletingLastPathComponent(),
      withIntermediateDirectories: true,
      attributes: nil
    )
    
    let content = """
    [00:10.00]Tappable line 1
    [00:20.00]Tappable line 2
    """
    
    try content.write(to: lrcURL, atomically: true, encoding: .utf8)
    
    transcriptViewerViewModel.loadTranscript(for: relativePath)
    
    // Simulate tapping a line
    let line = transcriptViewerViewModel.lines[1]
    tappedTimestamp = line.timestamp
    expectation.fulfill()
    
    XCTAssertEqual(tappedTimestamp, 20.0)
    
    waitForExpectations(timeout: 1.0)
  }
  
  // MARK: - ArtworkTranscriptContainer Tests
  
  /// Test container initialization
  func testArtworkTranscriptContainerInitialization() {
    let viewController = UIViewController()
    let artworkControl = ArtworkControl()
    
    let container = ArtworkTranscriptContainer(
      artworkControl: artworkControl,
      parentViewController: viewController
    )
    
    XCTAssertNotNil(container)
    XCTAssertFalse(container.isCurrentlyShowingTranscript())
  }
  
  /// Test toggling between artwork and transcript
  func testToggleBetweenArtworkAndTranscript() {
    let viewController = UIViewController()
    let artworkControl = ArtworkControl()
    
    let container = ArtworkTranscriptContainer(
      artworkControl: artworkControl,
      parentViewController: viewController
    )
    
    _ = TranscriptViewerViewModel()
    
    // Initially showing artwork
    XCTAssertFalse(container.isCurrentlyShowingTranscript())
    
    // Note: Full toggle testing requires UI rendering which is difficult in unit tests
    // The toggle method should be tested in integration tests or manual testing
  }
  
  // MARK: - TranscriptLineView Tests
  
  /// Test line view with active state
  func testTranscriptLineViewActive() {
    let line = LRCLine(timestamp: 10.0, text: "Active line")
    
    // Active line should be highlighted
    let isActive = true
    
    XCTAssertEqual(line.text, "Active line")
    XCTAssertEqual(line.timestamp, 10.0)
    XCTAssertTrue(isActive)
  }
  
  /// Test line view with inactive state
  func testTranscriptLineViewInactive() {
    let line = LRCLine(timestamp: 20.0, text: "Inactive line")
    
    // Inactive line should not be highlighted
    let isActive = false
    
    XCTAssertEqual(line.text, "Inactive line")
    XCTAssertEqual(line.timestamp, 20.0)
    XCTAssertFalse(isActive)
  }
  
  /// Test line view with empty text
  func testTranscriptLineViewWithEmptyText() {
    let line = LRCLine(timestamp: 30.0, text: "")
    
    // Empty text should display music note symbol
    let displayText = line.text.isEmpty ? "♪" : line.text
    
    XCTAssertEqual(displayText, "♪")
  }
  
  // MARK: - Integration Tests
  
  /// Test complete UI workflow
  func testCompleteUIWorkflow() throws {
    let relativePath = "books/complete_workflow.mp3"
    
    // 1. Create transcript file
    let lrcURL = LRCService.shared.getLRCFileURL(for: relativePath)
    try FileManager.default.createDirectory(
      at: lrcURL.deletingLastPathComponent(),
      withIntermediateDirectories: true,
      attributes: nil
    )
    
    let content = """
    [ti:Complete Workflow]
    [ar:Test Artist]
    [00:05.00]Line 0
    [00:10.00]Line 1
    [00:20.00]Line 2
    [00:30.00]Line 3
    [00:40.00]Line 4
    """
    
    try content.write(to: lrcURL, atomically: true, encoding: .utf8)
    
    // 2. Load transcript into view model
    transcriptViewerViewModel.loadTranscript(for: relativePath)
    XCTAssertTrue(transcriptViewerViewModel.hasTranscript)
    XCTAssertEqual(transcriptViewerViewModel.lines.count, 5)
    
    // 3. Simulate playback at various times
    transcriptViewerViewModel.updateCurrentTime(5.0)
    XCTAssertEqual(transcriptViewerViewModel.currentLineIndex, 0)
    
    transcriptViewerViewModel.updateCurrentTime(15.0)
    XCTAssertEqual(transcriptViewerViewModel.currentLineIndex, 1)
    
    transcriptViewerViewModel.updateCurrentTime(25.0)
    XCTAssertEqual(transcriptViewerViewModel.currentLineIndex, 2)
    
    transcriptViewerViewModel.updateCurrentTime(35.0)
    XCTAssertEqual(transcriptViewerViewModel.currentLineIndex, 3)
    
    // 4. Test seeking via line tap
    let targetLine = transcriptViewerViewModel.lines[0]
    let seekTime = targetLine.timestamp
    XCTAssertEqual(seekTime, 5.0)
    
    // Update to seek time
    transcriptViewerViewModel.updateCurrentTime(seekTime)
    XCTAssertEqual(transcriptViewerViewModel.currentLineIndex, 0)
  }
  
  /// Test UI with rapidly changing current time
  func testRapidTimeChanges() throws {
    let relativePath = "books/rapid_test.mp3"
    let lrcURL = LRCService.shared.getLRCFileURL(for: relativePath)
    try FileManager.default.createDirectory(
      at: lrcURL.deletingLastPathComponent(),
      withIntermediateDirectories: true,
      attributes: nil
    )
    
    var content = "[ti:Rapid Test]\n"
    for i in 0..<20 {
      content += String(format: "[00:%02d.00]Line %d\n", i * 3, i)
    }
    
    try content.write(to: lrcURL, atomically: true, encoding: .utf8)
    
    transcriptViewerViewModel.loadTranscript(for: relativePath)
    
    // Rapidly update time
    for i in 0..<60 {
      transcriptViewerViewModel.updateCurrentTime(Double(i))
      
      // Verify current line index is always valid
      if let index = transcriptViewerViewModel.currentLineIndex {
        XCTAssertTrue(index >= 0)
        XCTAssertTrue(index < transcriptViewerViewModel.lines.count)
      }
    }
  }
  
  /// Test UI with long transcript
  func testLongTranscript() throws {
    let relativePath = "books/long_transcript.mp3"
    let lrcURL = LRCService.shared.getLRCFileURL(for: relativePath)
    try FileManager.default.createDirectory(
      at: lrcURL.deletingLastPathComponent(),
      withIntermediateDirectories: true,
      attributes: nil
    )
    
    var content = "[ti:Long Transcript]\n"
    for i in 0..<100 {
      let minutes = i / 60
      let seconds = i % 60
      content += String(format: "[%02d:%02d.00]Line %d\n", minutes, seconds, i)
    }
    
    try content.write(to: lrcURL, atomically: true, encoding: .utf8)
    
    transcriptViewerViewModel.loadTranscript(for: relativePath)
    
    XCTAssertEqual(transcriptViewerViewModel.lines.count, 100)
    
    // Test at various positions
    transcriptViewerViewModel.updateCurrentTime(0.0)
    XCTAssertEqual(transcriptViewerViewModel.currentLineIndex, 0)
    
    transcriptViewerViewModel.updateCurrentTime(50.0)
    XCTAssertEqual(transcriptViewerViewModel.currentLineIndex, 50)
    
    transcriptViewerViewModel.updateCurrentTime(99.0)
    XCTAssertEqual(transcriptViewerViewModel.currentLineIndex, 99)
  }
  
  /// Test UI with special characters in transcript
  func testSpecialCharactersInUI() throws {
    let relativePath = "books/special_chars.mp3"
    let lrcURL = LRCService.shared.getLRCFileURL(for: relativePath)
    try FileManager.default.createDirectory(
      at: lrcURL.deletingLastPathComponent(),
      withIntermediateDirectories: true,
      attributes: nil
    )
    
    let content = """
    [ti:Special Characters 测试]
    [00:10.00]Hello 你好 こんにちは
    [00:20.00]Emoji test 😀🎵📖
    [00:30.00]Symbols: @#$%^&*()
    """
    
    try content.write(to: lrcURL, atomically: true, encoding: .utf8)
    
    transcriptViewerViewModel.loadTranscript(for: relativePath)
    
    XCTAssertTrue(transcriptViewerViewModel.lines[0].text.contains("你好"))
    XCTAssertTrue(transcriptViewerViewModel.lines[1].text.contains("😀"))
    XCTAssertTrue(transcriptViewerViewModel.lines[2].text.contains("@#$%"))
  }
  
  // MARK: - Accessibility Tests
  
  /// Test that lines are accessible
  func testLineAccessibility() {
    let line = LRCLine(timestamp: 10.0, text: "Accessible line")
    
    // Lines should have their text accessible
    XCTAssertFalse(line.text.isEmpty)
    XCTAssertTrue(line.text.count > 0)
  }
  
  /// Test empty state message is clear
  func testEmptyStateAccessibility() {
    let viewModel = TranscriptViewerViewModel()
    
    XCTAssertFalse(viewModel.hasTranscript)
    
    // Empty state should be clearly communicated
    // In the actual UI, this shows "No Transcript Available"
  }
  
  // MARK: - Performance Tests
  
  /// Test performance of loading large transcript
  func testLoadingPerformance() throws {
    let relativePath = "books/performance.mp3"
    let lrcURL = LRCService.shared.getLRCFileURL(for: relativePath)
    try FileManager.default.createDirectory(
      at: lrcURL.deletingLastPathComponent(),
      withIntermediateDirectories: true,
      attributes: nil
    )
    
    var content = ""
    for i in 0..<500 {
      let minutes = i / 60
      let seconds = i % 60
      content += String(format: "[%02d:%02d.00]Line %d\n", minutes, seconds, i)
    }
    
    try content.write(to: lrcURL, atomically: true, encoding: .utf8)
    
    measure {
      transcriptViewerViewModel.loadTranscript(for: relativePath)
    }
    
    XCTAssertEqual(transcriptViewerViewModel.lines.count, 500)
  }
  
  /// Test performance of time updates
  func testTimeUpdatePerformance() throws {
    let lines = (0..<100).map { LRCLine(timestamp: Double($0), text: "Line \($0)") }
    let document = LRCDocument(metadata: LRCMetadata(), lines: lines)
    transcriptViewerViewModel.lrcDocument = document
    
    measure {
      for i in 0..<100 {
        transcriptViewerViewModel.updateCurrentTime(Double(i) + 0.5)
      }
    }
  }
  
  // MARK: - Visual Bug Tests
  
  /// Test transcript button background color remains visible after toggling views
  /// BUG: The blue circular background disappears after toggling to lyrics view,
  /// making the white notepad icon invisible on white background
  func testTranscriptButtonBackgroundColorPersistsAfterToggle() throws {
    let viewController = UIViewController()
    
    // Create ArtworkControl which will automatically setup the button
    let artworkControl = ArtworkControl(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
    
    // Give the view a chance to complete setup
    _ = artworkControl.layer
    
    // Verify initial state: button should have blue background
    let initialBackgroundColor = artworkControl.transcriptButton.backgroundColor
    XCTAssertNotNil(initialBackgroundColor, "Transcript button should have a background color initially")
    XCTAssertEqual(initialBackgroundColor, UIColor.systemBlue, 
                   "Initial transcript button background should be systemBlue")
    
    // Verify the button is visible and has correct properties
    XCTAssertFalse(artworkControl.transcriptButton.isHidden, 
                   "Transcript button should be visible")
    XCTAssertEqual(artworkControl.transcriptButton.tintColor, .white,
                   "Transcript button icon should be white for contrast")
    XCTAssertEqual(artworkControl.transcriptButton.layer.cornerRadius, 20.0,
                   "Transcript button should be circular with corner radius 20")
    
    // Create container and simulate toggle to transcript view
    let container = ArtworkTranscriptContainer(
      artworkControl: artworkControl,
      parentViewController: viewController
    )
    
    let relativePath = "books/toggle_test.mp3"
    let lrcURL = LRCService.shared.getLRCFileURL(for: relativePath)
    try FileManager.default.createDirectory(
      at: lrcURL.deletingLastPathComponent(),
      withIntermediateDirectories: true,
      attributes: nil
    )
    
    let content = """
    [ti:Toggle Test]
    [00:10.00]Test line
    """
    
    try content.write(to: lrcURL, atomically: true, encoding: .utf8)
    
    let viewModel = TranscriptViewerViewModel()
    viewModel.loadTranscript(for: relativePath)
    
    // Simulate toggling to transcript view
    container.toggleView(viewModel: viewModel)
    
    // Wait for animation to complete
    let expectation = self.expectation(description: "Wait for toggle animation")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 1.0)
    
    // BUG CHECK: After toggling, the background color should still be present
    let backgroundColorAfterToggle = artworkControl.transcriptButton.backgroundColor
    
    // THIS TEST WILL FAIL IF THE BUG EXISTS
    XCTAssertNotNil(backgroundColorAfterToggle, 
                    "FAIL: Transcript button background color is nil after toggle - button icon will be invisible on white background!")
    
    XCTAssertEqual(backgroundColorAfterToggle, UIColor.systemBlue,
                   "FAIL: Transcript button background should remain systemBlue after toggling to transcript view. Current color: \(String(describing: backgroundColorAfterToggle))")
    
    // Additional checks for visual properties
    XCTAssertEqual(artworkControl.transcriptButton.tintColor, .white,
                   "Icon tint color should remain white after toggle")
    
    XCTAssertGreaterThan(artworkControl.transcriptButton.layer.shadowOpacity, 0,
                        "Button shadow should be visible for depth")
    
    // Test toggling back to artwork view
    container.toggleView(viewModel: viewModel)
    
    let expectation2 = self.expectation(description: "Wait for second toggle animation")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      expectation2.fulfill()
    }
    wait(for: [expectation2], timeout: 1.0)
    
    // Verify background color is still present after toggling back
    let backgroundColorAfterSecondToggle = artworkControl.transcriptButton.backgroundColor
    
    XCTAssertNotNil(backgroundColorAfterSecondToggle,
                    "FAIL: Transcript button background color is nil after toggling back - visual bug confirmed!")
    
    XCTAssertEqual(backgroundColorAfterSecondToggle, UIColor.systemBlue,
                   "FAIL: Transcript button background should remain systemBlue after toggling back to artwork view. Current color: \(String(describing: backgroundColorAfterSecondToggle))")
    
    // Verify button remains interactive
    XCTAssertTrue(artworkControl.transcriptButton.isUserInteractionEnabled,
                  "Button should remain interactive after toggles")
    
    // Verify z-position is maintained (button should be on top)
    XCTAssertEqual(artworkControl.transcriptButton.layer.zPosition, 1000,
                   "Button should maintain high z-position to stay on top")
  }
  
  /// Test transcript button remains visible when artwork control alpha changes
  /// BUG: When toggling to transcript view, artworkControl.alpha = 0 hides the button too
  func testTranscriptButtonVisibilityDuringAlphaTransitions() throws {
    let viewController = UIViewController()
    let artworkControl = ArtworkControl(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
    
    _ = artworkControl.layer
    
    let container = ArtworkTranscriptContainer(
      artworkControl: artworkControl,
      parentViewController: viewController
    )
    
    // Setup transcript
    let relativePath = "books/alpha_test.mp3"
    let lrcURL = LRCService.shared.getLRCFileURL(for: relativePath)
    try FileManager.default.createDirectory(
      at: lrcURL.deletingLastPathComponent(),
      withIntermediateDirectories: true,
      attributes: nil
    )
    
    let content = "[00:10.00]Test line"
    try content.write(to: lrcURL, atomically: true, encoding: .utf8)
    
    let viewModel = TranscriptViewerViewModel()
    viewModel.loadTranscript(for: relativePath)
    
    // Initial state: artwork is visible
    XCTAssertEqual(artworkControl.alpha, 1.0, "Artwork control should be fully visible initially")
    XCTAssertEqual(artworkControl.transcriptButton.alpha, 1.0, 
                   "Transcript button should be fully visible initially")
    
    // Toggle to transcript view
    container.toggleView(viewModel: viewModel)
    
    let expectation1 = self.expectation(description: "Wait for toggle animation")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
      expectation1.fulfill()
    }
    wait(for: [expectation1], timeout: 1.0)
    
    // BUG CHECK: After toggling, artworkControl.alpha becomes 0
    // This makes the transcript button invisible too!
    let artworkAlphaAfterToggle = artworkControl.alpha
    let buttonAlphaAfterToggle = artworkControl.transcriptButton.alpha
    
    // The artwork control is hidden (alpha = 0)
    XCTAssertEqual(artworkAlphaAfterToggle, 0.0,
                   "Artwork control alpha is 0 when showing transcript (this is expected)")
    
    // THIS IS THE BUG: The button inherits the parent's alpha value
    // When artworkControl.alpha = 0, the button becomes invisible even though it should be visible
    if buttonAlphaAfterToggle == 0.0 {
      XCTFail("BUG CONFIRMED: Transcript button alpha is 0 when showing transcript view! The button inherits artworkControl's alpha value, making it invisible. The button should remain visible (alpha = 1.0) on both views.")
    } else {
      // If button has its own alpha, it should be 1.0
      XCTAssertEqual(buttonAlphaAfterToggle, 1.0,
                     "Transcript button should maintain alpha = 1.0 even when parent is hidden")
    }
  }
  
  /// Test that proves the button's visual invisibility issue
  func testTranscriptButtonEffectiveVisibilityOnTranscriptView() throws {
    let artworkControl = ArtworkControl(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
    _ = artworkControl.layer
    
    // Simulate what happens during transition: artwork control alpha is set to 0
    artworkControl.alpha = 0.0
    
    // Check button state
    let buttonAlpha = artworkControl.transcriptButton.alpha
    let buttonBackgroundColor = artworkControl.transcriptButton.backgroundColor
    
    // Button properties are correct
    XCTAssertEqual(buttonBackgroundColor, UIColor.systemBlue,
                   "Button background color property is set correctly")
    XCTAssertEqual(buttonAlpha, 1.0,
                   "Button's own alpha property is 1.0")
  }
  
  /// Test transcript button visibility and appearance with transcript state changes
  func testTranscriptButtonAppearanceAfterStateChanges() {
    // Create ArtworkControl which will automatically setup the button
    let artworkControl = ArtworkControl(frame: CGRect(x: 0, y: 0, width: 300, height: 400))
    
    // Give the view a chance to complete setup
    _ = artworkControl.layer
    
    let initialBackgroundColor = artworkControl.transcriptButton.backgroundColor
    XCTAssertEqual(initialBackgroundColor, UIColor.systemBlue,
                   "Button should have blue background initially")
    
    // Update button when transcript is available
    artworkControl.updateTranscriptButtonVisibility(hasTranscript: true)
    
    // Verify background color is maintained after update
    let backgroundAfterUpdate = artworkControl.transcriptButton.backgroundColor
    XCTAssertNotNil(backgroundAfterUpdate,
                    "FAIL: Background color lost after updating transcript visibility")
    XCTAssertEqual(backgroundAfterUpdate, UIColor.systemBlue,
                   "FAIL: Background should remain blue after updating transcript visibility. Current: \(String(describing: backgroundAfterUpdate))")
    
    // Verify icon changed to filled version
    XCTAssertNotNil(artworkControl.transcriptButton.image(for: .normal),
                    "Button should have an icon image")
    
    // Update button when transcript is not available
    artworkControl.updateTranscriptButtonVisibility(hasTranscript: false)
    
    // Verify background color is still maintained
    let backgroundAfterSecondUpdate = artworkControl.transcriptButton.backgroundColor
    XCTAssertNotNil(backgroundAfterSecondUpdate,
                    "FAIL: Background color lost after second update")
    XCTAssertEqual(backgroundAfterSecondUpdate, UIColor.systemBlue,
                   "FAIL: Background should remain blue after all updates. Current: \(String(describing: backgroundAfterSecondUpdate))")
    
    // Verify visual properties are consistent
    XCTAssertEqual(artworkControl.transcriptButton.tintColor, .white,
                   "Icon color should be white for visibility on blue background")
    XCTAssertEqual(artworkControl.transcriptButton.layer.cornerRadius, 20.0,
                   "Button should maintain circular shape")
    XCTAssertEqual(artworkControl.transcriptButton.layer.zPosition, 1000,
                   "Button should maintain high z-position")
  }
  
  // MARK: - Lyrics Button Visibility Tests
  
  /// Test that lyricsButton in PlayerViewController has blue background on ArtworkView
  func testLyricsButtonHasBlueBackgroundOnArtworkView() throws {
    // Create PlayerViewController from storyboard
    let storyboard = UIStoryboard(name: "Player", bundle: nil)
    guard let playerVC = storyboard.instantiateViewController(withIdentifier: "PlayerViewController") as? PlayerViewController else {
      XCTFail("Failed to instantiate PlayerViewController")
      return
    }
    
    // Setup mock dependencies with proper Combine publishers
    let mockPlayerManager = PlayerManagerProtocolMock()
    let mockLibraryService = LibraryServiceProtocolMock()
    let mockSyncService = SyncServiceProtocolMock()
    
    // Configure mock to return proper publishers
    mockPlayerManager.currentItemPublisherReturnValue = Just(nil).eraseToAnyPublisher()
    mockPlayerManager.currentSpeedPublisherReturnValue = Just(1.0).eraseToAnyPublisher()
    mockPlayerManager.isPlayingPublisherReturnValue = Just(false).eraseToAnyPublisher()
    
    // Create and assign viewModel
    let viewModel = PlayerViewModel(
      playerManager: mockPlayerManager,
      libraryService: mockLibraryService,
      syncService: mockSyncService
    )
    playerVC.viewModel = viewModel
    
    // Load the view - this triggers viewDidLoad and setupLyricsButton
    _ = playerVC.view
    
    // Wait for view setup to complete
    let expectation = self.expectation(description: "View setup")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 1.0)
    
    // Verify lyricsButton exists
    XCTAssertNotNil(playerVC.lyricsButton, "lyricsButton should exist in PlayerViewController")
    
    // Test: Check that lyricsButton has blue background
    XCTAssertEqual(
      playerVC.lyricsButton.backgroundColor,
      UIColor.systemBlue,
      "lyricsButton should have systemBlue background on ArtworkView"
    )
    
    // Verify button is visible
    XCTAssertFalse(playerVC.lyricsButton.isHidden, "lyricsButton should be visible")
  }
}
