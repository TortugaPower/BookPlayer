import Combine
import XCTest

@testable import BookPlayer
@testable import BookPlayerKit

@MainActor
final class ImportManagerTests: XCTestCase {
  func testBatchPublishesOneSnapshotPreservingPendingFilesAndFilteringFolders() throws {
    let manager = ImportManager(libraryService: LibraryServiceProtocolMock())
    let root = URL(fileURLWithPath: "/import-tests", isDirectory: true)
    let pending = root.appendingPathComponent("pending.mp3")
    let first = root.appendingPathComponent("first.mp3")
    let second = root.appendingPathComponent("second.mp3")
    manager.process(pending)
    var snapshots = [Set<URL>]()
    let subscription = manager.observeFiles().dropFirst().sink { snapshots.append(Set($0)) }
    defer { subscription.cancel() }

    manager.process([
      first, second, first, pending,
      root.appendingPathComponent(DataManager.processedFolderName),
      root.appendingPathComponent(DataManager.inboxFolderName),
      root.appendingPathComponent(DataManager.backupFolderName),
    ])

    XCTAssertEqual(snapshots, [Set([pending, first, second])])
    let operation = try XCTUnwrap(manager.prepareOperation())
    XCTAssertEqual(Set(operation.files), Set([pending, first, second]))
  }

  func testEmptyOrFilteredBatchDoesNotPublish() {
    let manager = ImportManager(libraryService: LibraryServiceProtocolMock())
    let root = URL(fileURLWithPath: "/import-tests", isDirectory: true)
    var publications = 0
    let subscription = manager.observeFiles().dropFirst().sink { _ in publications += 1 }
    defer { subscription.cancel() }

    manager.process([])
    manager.process([
      root.appendingPathComponent(DataManager.processedFolderName),
      root.appendingPathComponent(DataManager.inboxFolderName),
      root.appendingPathComponent(DataManager.backupFolderName),
    ])

    XCTAssertEqual(publications, 0)
    XCTAssertFalse(manager.hasPendingFiles())
  }

  func testSingleFileNotificationsStillPublishForAnAlreadyPendingURL() {
    let manager = ImportManager(libraryService: LibraryServiceProtocolMock())
    let file = URL(fileURLWithPath: "/import-tests/chapter.mp3")
    var snapshots = [Set<URL>]()
    let subscription = manager.observeFiles().dropFirst().sink { snapshots.append(Set($0)) }
    defer { subscription.cancel() }

    manager.process(file)
    manager.process(file)

    XCTAssertEqual(snapshots, [Set([file]), Set([file])])
  }
}
