//
//  ImportOperationTests.swift
//  BookPlayerTests
//
//  Created by Gianni Carlo on 9/13/18.
//  Copyright © 2018 BookPlayer LLC. All rights reserved.
//

@testable import BookPlayer
@testable import BookPlayerKit
import Combine
import XCTest

// MARK: - processFiles()

class ImportOperationTests: XCTestCase {
  override func setUp() {
    super.setUp()
    // Put setup code here. This method is called before the invocation of each test method in the class.
    let documentsFolder = DataManager.getDocumentsFolderURL()
    DataTestUtils.clearFolderContents(url: documentsFolder)
    let sharedFolder = DataManager.getSharedFilesFolderURL()
    DataTestUtils.clearFolderContents(url: sharedFolder)
  }

  func testProcessOneFile() {
    let filename = "file.txt"
    let bookContents = "bookcontents".data(using: .utf8)!
    let documentsFolder = DataManager.getDocumentsFolderURL()

    // Add test file to Documents folder
    let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: documentsFolder)

    let promise = XCTestExpectation(description: "Process file")
    let promiseFile = expectation(forNotification: .processingFile, object: nil)
    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))
    let audioMetadataService = AudioMetadataService()
    let libraryService = LibraryService()
    libraryService.setup(dataManager: dataManager, audioMetadataService: audioMetadataService)
    let operation = ImportOperation(files: [fileUrl],
                                    libraryService: libraryService)

    operation.completionBlock = {
      // Test file should no longer be in the Documents folder,
      // but when testing on simulator, the security scope is resolved
      XCTAssert(!FileManager.default.fileExists(atPath: fileUrl.path))

      XCTAssertNotNil(operation.files.first)
      XCTAssertNotNil(operation.processedFiles.first)

      let processedFile = operation.processedFiles.first!

      // Test file exists in new location
      XCTAssert(FileManager.default.fileExists(atPath: processedFile.path))

      let content = FileManager.default.contents(atPath: processedFile.path)!
      XCTAssert(content == bookContents)

      promise.fulfill()
    }

    operation.start()

    wait(for: [promise, promiseFile], timeout: 15)
  }

  func testProcessFileFromSharedFolder() {
    let filename = "shared_file.txt"
    let bookContents = "sharedbookcontents".data(using: .utf8)!
    let sharedFolder = DataManager.getSharedFilesFolderURL()

    // Add test file to the App Group SharedFiles folder (Share-extension drop location)
    let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: sharedFolder)

    let promise = XCTestExpectation(description: "Process shared file")
    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))
    let audioMetadataService = AudioMetadataService()
    let libraryService = LibraryService()
    libraryService.setup(dataManager: dataManager, audioMetadataService: audioMetadataService)
    let operation = ImportOperation(files: [fileUrl], libraryService: libraryService)

    operation.completionBlock = {
      // Source in SharedFiles should be cleaned up after import (isAppManagedSource)
      XCTAssertFalse(FileManager.default.fileExists(atPath: fileUrl.path))

      XCTAssertNotNil(operation.processedFiles.first)
      let processedFile = operation.processedFiles.first!
      XCTAssert(FileManager.default.fileExists(atPath: processedFile.path))
      XCTAssertEqual(FileManager.default.contents(atPath: processedFile.path), bookContents)

      promise.fulfill()
    }

    operation.start()

    wait(for: [promise], timeout: 15)
  }

  func testProcessFileFromInboxFolder() throws {
    let filename = "inbox_file.txt"
    let bookContents = "inboxbookcontents".data(using: .utf8)!
    let inboxFolder = DataManager.getInboxFolderURL()
    try FileManager.default.createDirectory(at: inboxFolder, withIntermediateDirectories: true)

    // Add test file to the Documents/Inbox folder (system inbox for document interactions)
    let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: inboxFolder)

    let promise = XCTestExpectation(description: "Process inbox file")
    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))
    let audioMetadataService = AudioMetadataService()
    let libraryService = LibraryService()
    libraryService.setup(dataManager: dataManager, audioMetadataService: audioMetadataService)
    let operation = ImportOperation(files: [fileUrl], libraryService: libraryService)

    operation.completionBlock = {
      // Source in Inbox (a Documents subfolder) should be cleaned up after import
      XCTAssertFalse(FileManager.default.fileExists(atPath: fileUrl.path))

      XCTAssertNotNil(operation.processedFiles.first)
      let processedFile = operation.processedFiles.first!
      XCTAssert(FileManager.default.fileExists(atPath: processedFile.path))
      XCTAssertEqual(FileManager.default.contents(atPath: processedFile.path), bookContents)

      promise.fulfill()
    }

    operation.start()

    wait(for: [promise], timeout: 15)
  }
}

// MARK: - Virtual import pipeline

@MainActor
final class VirtualImportPipelineTests: XCTestCase {
  private struct StubItem {
    let id: String
  }

  private func makeResource(id: String) -> SimpleExternalResource {
    SimpleExternalResource(
      providerName: "jellyfin",
      providerId: id,
      syncStatus: ExternalResource.SyncStatus.stream.rawValue,
      lastSyncedAt: nil,
      libraryItem: nil
    )
  }

  func testBuildsOnlyHydratedItemsInSelectionOrder() async throws {
    let items = [StubItem(id: "a"), StubItem(id: "b"), StubItem(id: "c")]
    let resources = try await VirtualImportPipeline.run(
      items: items,
      id: \.id,
      hydrateExtensions: { ids in
        XCTAssertEqual(ids, ["a", "b", "c"])
        return ["a": "m4b", "c": "mp3"]  // "b" reports no audio-file metadata
      },
      buildResource: { item, _ in self.makeResource(id: item.id) }
    )
    XCTAssertEqual(resources.map(\.providerId), ["a", "c"], "skips unhydrated items, keeps selection order")
  }

  func testEmptySelectionNeverHydrates() async throws {
    var hydrateCalled = false
    let resources = try await VirtualImportPipeline.run(
      items: [StubItem](),
      id: \.id,
      hydrateExtensions: { _ in
        hydrateCalled = true
        return [:]
      },
      buildResource: { item, _ in self.makeResource(id: item.id) }
    )
    XCTAssertTrue(resources.isEmpty)
    XCTAssertFalse(hydrateCalled, "no selection means no network round-trip")
  }

  func testHydrationErrorsPropagate() async {
    do {
      _ = try await VirtualImportPipeline.run(
        items: [StubItem(id: "a")],
        id: \.id,
        hydrateExtensions: { _ in throw URLError(.notConnectedToInternet) },
        buildResource: { item, _ in self.makeResource(id: item.id) }
      )
      XCTFail("expected the hydration error to propagate to the caller's error state")
    } catch {
      XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet)
    }
  }
}

// MARK: - External import confirmation

@MainActor
final class ExternalImportViewModelTests: XCTestCase {
  private func makeBatch(ids: [String]) -> ExternalImportBatch {
    ExternalImportBatch(
      resources: ids.map {
        SimpleExternalResource(
          providerName: "jellyfin",
          providerId: $0,
          syncStatus: ExternalResource.SyncStatus.stream.rawValue,
          lastSyncedAt: nil,
          libraryItem: nil
        )
      }
    )
  }

  func testRemovalMutatesOwnedStateAndPublishes() {
    let sut = ExternalImportViewModel(batch: makeBatch(ids: ["a", "b"]), onConfirm: { _ in })
    var published = false
    let subscription = sut.objectWillChange.sink { published = true }

    sut.removeResource(withId: "a")

    XCTAssertEqual(sut.resources.map(\.providerId), ["b"])
    XCTAssertTrue(published, "removal must republish — the old mailbox passthrough left the delete button visually dead")
    subscription.cancel()
  }

  func testConfirmHandsBackTheEditedSelection() {
    var confirmed: [SimpleExternalResource]?
    let sut = ExternalImportViewModel(batch: makeBatch(ids: ["a", "b"]), onConfirm: { confirmed = $0 })

    sut.removeResource(withId: "b")
    sut.confirm()

    XCTAssertEqual(confirmed?.map(\.providerId), ["a"], "confirm sends the batch as edited, not as staged")
  }
}
