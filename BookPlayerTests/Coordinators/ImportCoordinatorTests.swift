//
//  ImportCoordinatorTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Combine
import XCTest

@testable import BookPlayer
@testable import BookPlayerKit

/// A fast import (one small file) used to finish while the import screen was still closing, and
/// the library's placement prompt, presented then, was dropped. The import now starts once the
/// screen has closed.
@MainActor
final class ImportCoordinatorTests: XCTestCase {
  private var file: URL!

  override func setUpWithError() throws {
    file = FileManager.default.temporaryDirectory.appendingPathComponent("import-\(UUID().uuidString).mp3")
    try Data("audio".utf8).write(to: file)
  }

  override func tearDown() {
    try? FileManager.default.removeItem(at: file)
    super.tearDown()
  }

  func testConfirmingStartsTheImportOnlyOnceTheScreenHasClosed() throws {
    let importManager = ImportManager(libraryService: LibraryServiceProtocolMock())
    importManager.process(file)
    var startedImports = 0
    let subscription = importManager.operationPublisher.sink { _ in startedImports += 1 }
    defer { subscription.cancel() }

    let flow = HeldDismissalFlow()
    let coordinator = ImportCoordinator(flow: flow, importManager: importManager)
    coordinator.start()
    let screen = try XCTUnwrap(flow.presented as? ImportViewController)

    screen.viewModel.createOperation()

    XCTAssertTrue(flow.isDismissing)
    XCTAssertEqual(startedImports, 0, "the screen is still closing")

    flow.finishDismissal()

    XCTAssertEqual(startedImports, 1)
  }

  /// The import takes its files when Import is tapped: the closing screen's Cancel can no longer
  /// discard them.
  func testCancellingWhileTheScreenClosesKeepsTheConfirmedFiles() throws {
    let importManager = ImportManager(libraryService: LibraryServiceProtocolMock())
    importManager.process(file)
    var imported = [URL]()
    let subscription = importManager.operationPublisher.sink { imported.append(contentsOf: $0.files) }
    defer { subscription.cancel() }

    let flow = HeldDismissalFlow()
    let coordinator = ImportCoordinator(flow: flow, importManager: importManager)
    coordinator.start()
    let screen = try XCTUnwrap(flow.presented as? ImportViewController)

    screen.viewModel.createOperation()
    try screen.viewModel.discardImportOperation()
    flow.finishDismissal()

    XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    XCTAssertEqual(imported, [file])
  }

  /// The library's placement prompt waits for the import screen, however it closes: Import, Cancel,
  /// swiped down, or taken down with what it was presented over.
  func testTheScreenCountsAsShownUntilItHasDisappeared() throws {
    let importManager = ImportManager(libraryService: LibraryServiceProtocolMock())
    importManager.process(file)
    let flow = HeldDismissalFlow()
    let coordinator = ImportCoordinator(flow: flow, importManager: importManager)
    coordinator.start()
    let screen = try XCTUnwrap(flow.presented as? ImportViewController)

    screen.beginAppearanceTransition(true, animated: false)
    XCTAssertTrue(importManager.isImportScreenShown)
    screen.endAppearanceTransition()

    screen.beginAppearanceTransition(false, animated: false)
    XCTAssertTrue(importManager.isImportScreenShown, "still leaving")
    screen.endAppearanceTransition()

    XCTAssertFalse(importManager.isImportScreenShown)
  }

  /// Cancelling discards the files and never imports.
  func testCancellingNeverImports() throws {
    let importManager = ImportManager(libraryService: LibraryServiceProtocolMock())
    importManager.process(file)
    var startedImports = 0
    let subscription = importManager.operationPublisher.sink { _ in startedImports += 1 }
    defer { subscription.cancel() }

    let flow = HeldDismissalFlow()
    let coordinator = ImportCoordinator(flow: flow, importManager: importManager)
    coordinator.start()
    let screen = try XCTUnwrap(flow.presented as? ImportViewController)

    screen.viewModel.dismiss()
    flow.finishDismissal()

    XCTAssertEqual(startedImports, 0)
  }
}

/// A presentation flow whose dismissal finishes only when the test says so, as an animated one
/// finishes after its transition.
private final class HeldDismissalFlow: BPCoordinatorPresentationFlow {
  let navigationController = UINavigationController()
  private(set) var presented: UIViewController?
  private(set) var isDismissing = false
  private var pendingCompletion: (() -> Void)?

  func startPresentation(_ viewController: UIViewController, animated: Bool) {
    presented = viewController
  }

  func finishPresentation(animated: Bool, completion: (() -> Void)?) {
    isDismissing = true
    pendingCompletion = completion
  }

  func finishDismissal() {
    pendingCompletion?()
    pendingCompletion = nil
  }
}
