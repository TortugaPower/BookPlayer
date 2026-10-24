//
//  ReleaseCheckUITests.swift
//  BookPlayerUITests
//
//  Run only by the prepare-release-ios skill's release check (scripts/release-check), never by CI.
//  The script runs these one at a time, on one simulator per supported iOS version, and stages the
//  state each one expects (an empty install, test files in Documents, an older build's library).
//

import XCTest

final class ReleaseCheckUITests: XCTestCase {
  /// Names of the test files the script copies into the app's Documents folder
  static let bookPath = "Release Check Book.m4a"
  static let folderPath = "Release Check Folder"

  private var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    // Labels like "Done" and "Library" are matched in English
    app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
  }

  // MARK: - Scenarios

  /// Empty install: the Library tab shows and the app is still up 10 s later
  func testFreshLaunch() throws {
    app.launch()

    XCTAssertTrue(app.tabBars.buttons["Library"].waitForExistence(timeout: 30), "Library tab never appeared")
    sleep(10)
    assertStillRunning()
  }

  /// Test files in Documents → Import sheet → Done → "Library" → a book row and a folder row
  func testImport() throws {
    app.launch()

    importFilesIntoLibrary()

    XCTAssertTrue(row(Self.bookPath).waitForExistence(timeout: 30), "Book row never appeared")
    XCTAssertTrue(row(Self.folderPath).waitForExistence(timeout: 10), "Folder row never appeared")
    assertStillRunning()
  }

  /// Tap the book → open the player → the elapsed time moves while playing
  func testPlayback() throws {
    app.launch()

    let bookRow = row(Self.bookPath)
    XCTAssertTrue(bookRow.waitForExistence(timeout: 30), "Book row missing; run testImport first")
    bookRow.tap()

    let miniPlayer = app.descendants(matching: .any)["miniPlayer.info"]
    XCTAssertTrue(miniPlayer.waitForExistence(timeout: 15), "Mini player never appeared")
    miniPlayer.tap()

    let playPause = app.descendants(matching: .any)["player.playPause"]
    let currentTime = app.descendants(matching: .any)["player.currentTime"]
    XCTAssertTrue(playPause.waitForExistence(timeout: 15), "Player never opened")
    XCTAssertTrue(currentTime.exists, "Elapsed time isn't on the player")

    if playPause.label == "Play" {
      playPause.tap()
    }
    let start = currentTime.label
    sleep(5)
    XCTAssertEqual(playPause.label, "Pause", "Player isn't playing")
    XCTAssertNotEqual(currentTime.label, start, "Elapsed time didn't move in 5 s")

    playPause.tap()
    assertStillRunning()
  }

  /// After installing over the previous release: the library and its progress survived, and it still plays
  func testUpgradeContinuity() throws {
    app.launch()

    let bookRow = row(Self.bookPath)
    XCTAssertTrue(bookRow.waitForExistence(timeout: 30), "Book row from the previous release is gone")
    XCTAssertTrue(row(Self.folderPath).exists, "Folder row from the previous release is gone")
    let progress = percentCompleted(bookRow.label)
    XCTAssertNotNil(progress, "The book row's label has no progress percentage: \(bookRow.label)")
    XCTAssertGreaterThan(progress ?? 0, 0, "The book's progress was lost: \(bookRow.label)")
    assertStillRunning()

    try testPlayback()
  }

  // MARK: - Seeding an older build

  /// Runs against the PREVIOUS release, which has none of the identifiers above, so it only uses labels.
  /// Imports the test files and plays the book for a few seconds so it has progress to carry over.
  func testSeedPreviousRelease() throws {
    app.launch()

    importFilesIntoLibrary()

    let bookRow = app.descendants(matching: .any)
      .matching(NSPredicate(format: "label BEGINSWITH %@", Self.bookPath)).firstMatch
    XCTAssertTrue(bookRow.waitForExistence(timeout: 30), "Book row never appeared in the previous release")
    bookRow.tap()

    // Fail here as a seeding problem, not later as "progress lost" in the new build: a "Pause" button
    // (mini player) or the row's progress moving off 0 means the previous release is playing
    let deadline = Date().addingTimeInterval(15)
    var playing = false
    while !playing && Date() < deadline {
      playing = app.buttons["Pause"].exists || (percentCompleted(bookRow.label) ?? 0) > 0
      if !playing { sleep(1) }
    }
    XCTAssertTrue(playing, "The previous release never started playing the book (seeding problem): \(bookRow.label)")

    sleep(8)
    // Backgrounding saves the position
    XCUIDevice.shared.press(.home)
    sleep(3)
  }

  // MARK: - Helpers

  /// The progress in a book row's label ("…, 25 percent completed, …", from `voiceover_book_progress`), or nil
  /// when the label doesn't have it, so a reworded label fails instead of passing
  private func percentCompleted(_ label: String) -> Int? {
    guard let match = label.range(of: #"(\d+) percent completed"#, options: .regularExpression) else { return nil }
    return Int(label[match].prefix { $0.isNumber })
  }

  private func row(_ relativePath: String) -> XCUIElement {
    app.descendants(matching: .any)["library.row.\(relativePath)"]
  }

  private func importFilesIntoLibrary() {
    let done = app.navigationBars.buttons["Done"]
    XCTAssertTrue(done.waitForExistence(timeout: 30), "Import sheet never appeared")
    done.tap()

    // The placement prompt shows once the import sheet has closed
    let library = app.alerts.buttons["Library"].firstMatch
    XCTAssertTrue(library.waitForExistence(timeout: 30), "Placement prompt never appeared")
    library.tap()
  }

  private func assertStillRunning() {
    XCTAssertEqual(app.state, .runningForeground, "App isn't in the foreground")
  }
}
