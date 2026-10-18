//
//  TransferViewModelTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BrowserDrop
import Combine
import XCTest

@testable import BookPlayer
@testable import BookPlayerKit

/// The Transfer from Computer session, against a real BrowserDrop server on 127.0.0.1.
@MainActor
final class TransferViewModelTests: XCTestCase {
  private var stagingRoot: URL!
  private var importManager: ImportManager!
  private var operations: [ImportOperation] = []
  private var subscription: AnyCancellable?
  private var previousIdleTimerDisabled = false

  override func setUp() async throws {
    stagingRoot = FileManager.default.temporaryDirectory
      .appendingPathComponent("TransferViewModelTests-\(UUID().uuidString)", isDirectory: true)
    importManager = ImportManager(libraryService: LibraryServiceProtocolMock())
    operations = []
    subscription = importManager.operationPublisher.sink { [weak self] in self?.operations.append($0) }
    previousIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
    UIApplication.shared.isIdleTimerDisabled = false
  }

  override func tearDown() async throws {
    subscription?.cancel()
    for operation in operations {
      if let holding = operation.files.first?.deletingLastPathComponent() {
        try? FileManager.default.removeItem(at: holding)
      }
    }
    try? FileManager.default.removeItem(at: stagingRoot)
    UIApplication.shared.isIdleTimerDisabled = previousIdleTimerDisabled
  }

  func testRowsListTopLevelFilesAndFoldersWithTheirFileCounts() {
    let rows = TransferViewModel.rows(forRelativePaths: [
      "intro.mp3", "Book/01.mp3", "Other/a.mp3", "Book/Disc 2/02.mp3",
    ])

    XCTAssertEqual(rows.map(\.id), ["intro.mp3", "Book", "Other"])
    XCTAssertEqual(rows.map(\.icon), ["waveform", "folder", "folder"])
    XCTAssertNil(rows[0].subtitle)
    XCTAssertEqual(rows[1].subtitle, String.localizedStringWithFormat("files_title".localized, 2))
    XCTAssertEqual(rows[2].subtitle, String.localizedStringWithFormat("files_title".localized, 1))
  }

  /// Done moves what arrived into a holding folder and sends one import for it. A later Cancel or the
  /// sheet going away sends nothing more and leaves what Done handed over alone.
  func testDoneHandsWhatArrivedToOneImport() async throws {
    let model = makeModel()
    model.start()
    XCTAssertTrue(UIApplication.shared.isIdleTimerDisabled)
    let port = try await runningPort(of: model)

    try await upload("Book/01.mp3", to: port)
    try await waitUntil { model.fileCount == 1 }
    model.confirm()
    XCTAssertFalse(UIApplication.shared.isIdleTimerDisabled)
    try await waitUntil { !self.operations.isEmpty }

    let files = try XCTUnwrap(operations.first?.files)
    XCTAssertEqual(files.map(\.lastPathComponent), ["Book"])
    let holding = files[0].deletingLastPathComponent()
    XCTAssertEqual(
      holding.deletingLastPathComponent().standardizedFileURL.path,
      TransferViewModel.holdingRoot.standardizedFileURL.path
    )
    XCTAssertTrue(FileManager.default.fileExists(atPath: files[0].appendingPathComponent("01.mp3").path))

    model.discard()
    model.sheetDisappeared()
    try await Task.sleep(for: .milliseconds(300))
    XCTAssertEqual(operations.count, 1)
    XCTAssertTrue(FileManager.default.fileExists(atPath: files[0].appendingPathComponent("01.mp3").path))
    let state = await model.server.state
    XCTAssertEqual(state, .closed)
  }

  /// A removed folder takes its files with it: Done imports only what's left.
  func testRemovingAFolderDropsItsFilesFromTheImport() async throws {
    let model = makeModel()
    model.start()
    let port = try await runningPort(of: model)

    for path in ["Book/01.mp3", "Book/02.mp3", "intro.mp3"] {
      try await upload(path, to: port)
    }
    try await waitUntil { model.fileCount == 3 }
    XCTAssertEqual(model.rows.map(\.id), ["intro.mp3", "Book"])

    model.remove("Book")
    model.confirm()
    try await waitUntil { !self.operations.isEmpty }

    XCTAssertEqual(operations.first?.files.map(\.lastPathComponent), ["intro.mp3"])
  }

  /// Cancel throws away what arrived and imports nothing.
  func testCancelThrowsAwayWhatArrived() async throws {
    let model = makeModel()
    model.start()
    let port = try await runningPort(of: model)

    try await upload("intro.mp3", to: port)
    try await waitUntil { model.fileCount == 1 }
    // The session's staging folder, under the test's root: the configuration reached the server.
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: stagingRoot.path).count, 1)
    model.discard()
    XCTAssertFalse(UIApplication.shared.isIdleTimerDisabled)

    try await waitUntil {
      (try? FileManager.default.contentsOfDirectory(atPath: self.stagingRoot.path))?.isEmpty ?? false
    }
    try await Task.sleep(for: .milliseconds(300))
    XCTAssertTrue(operations.isEmpty)
  }

  // MARK: - Helpers

  private func makeModel() -> TransferViewModel {
    TransferViewModel(
      importManager: importManager,
      libraryService: LibraryServiceProtocolMock(),
      configuration: .init(
        ports: [0],
        allowedExtensions: TransferViewModel.acceptedExtensions,
        stagingRoot: stagingRoot
      )
    )
  }

  private func runningPort(of model: TransferViewModel) async throws -> UInt16 {
    try await waitUntil { model.status == .running }
    guard case .running(let port) = await model.server.state else {
      throw XCTSkip("The server isn't running")
    }
    return port
  }

  private func upload(_ path: String, to port: UInt16) async throws {
    let encoded = try XCTUnwrap(path.addingPercentEncoding(withAllowedCharacters: .alphanumerics))
    var request = URLRequest(url: try XCTUnwrap(URL(string: "http://127.0.0.1:\(port)/upload?path=\(encoded)")))
    request.httpMethod = "POST"
    request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
    let (_, response) = try await URLSession.shared.upload(for: request, from: Data("audio".utf8))
    XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 201, path)
  }

  private func waitUntil(
    timeout: Duration = .seconds(5),
    _ condition: @escaping () -> Bool,
    file: StaticString = #filePath,
    line: UInt = #line
  ) async throws {
    let deadline = ContinuousClock.now + timeout
    while !condition() {
      guard ContinuousClock.now < deadline else {
        XCTFail("Timed out waiting", file: file, line: line)
        return
      }
      try await Task.sleep(for: .milliseconds(20))
    }
  }
}
