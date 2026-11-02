//
//  StreamingLinkTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

@testable import BookPlayer
@testable import BookPlayerKit
import XCTest

/// Only a media-server link streams. Any matched book also has a Hardcover link, which has no file
/// behind it: with sync off, such a book still counts as downloaded and its missing file is reported
/// as missing, as before links existed, and a finished download never treats it as streamed.
final class StreamingLinkTests: XCTestCase {
  private var libraryService: LibraryService!

  override func setUp() {
    super.setUp()
    DataTestUtils.clearFolderContents(url: DataManager.getProcessedFolderURL())
    libraryService = LibraryService()
    libraryService.setup(
      dataManager: DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null")),
      audioMetadataService: AudioMetadataService()
    )
    _ = libraryService.getLibrary()
  }

  override func tearDown() {
    libraryService = nil
    super.tearDown()
  }

  // MARK: - Download state

  /// The download path would ask the BookPlayer API for the file, which a user without sync can't use
  func testWithSyncOffAHardcoverLinkedBookIsDownloaded() {
    let item = missingBook(links: [link(provider: "hardcover", status: .notSynced)])

    // Never set up: sync is off
    XCTAssertEqual(SyncService().getDownloadState(for: item), .downloaded)
  }

  func testWithSyncOffAStreamedBookWithoutItsFileIsNotDownloaded() {
    let item = missingBook(links: [link(provider: "jellyfin", status: .stream)])

    XCTAssertEqual(SyncService().getDownloadState(for: item), .notDownloaded)
  }

  // MARK: - Loading

  @MainActor
  func testLoadingAHardcoverLinkedBookWithoutItsFileReportsItMissing() async throws {
    let book = StubFactory.book(dataManager: libraryService.dataManager, title: "matched", duration: 100)
    libraryService.getLibraryReference().addToItems(book)
    libraryService.dataManager.saveContext()
    try FileManager.default.removeItem(at: DataManager.getProcessedFolderURL().appendingPathComponent(book.relativePath))
    _ = await libraryService.setExternalResource(providerName: "hardcover", providerId: "hc-1", for: book.uuid)
    // The link was written on the background context; read it on the view context
    libraryService.dataManager.getContext().refreshAllObjects()

    do {
      try await makeLoader().loadPlayer(book.relativePath, autoplay: false)
      XCTFail("expected fileMissing")
    } catch BPPlayerError.fileMissing(let relativePath) {
      XCTAssertEqual(relativePath, book.relativePath)
    }
  }

  /// The control: a streamed book has no file either, and goes on to stream from its server
  @MainActor
  func testLoadingAStreamedBookWithoutItsFileGoesOnToStreamIt() async throws {
    let inserted = await libraryService.insertItems(
      fromResources: [link(provider: "jellyfin", status: .stream, item: missingBook())],
      inside: nil
    )
    let book = try XCTUnwrap(inserted.first)
    libraryService.dataManager.getContext().refreshAllObjects()

    do {
      try await makeLoader().loadPlayer(book.relativePath, autoplay: false)
      XCTFail("expected the stubbed playback service to stop the load")
    } catch is LoadStopped {
      // Past the missing-file check
    }
  }

  // MARK: - Finished download

  /// Android's offload flips every downloaded link back to `stream`, Hardcover's included
  func testAFinishedDownloadPicksTheStreamedMediaServerLink() {
    let link = SyncService.streamedMediaServerLink(in: [
      syncable(provider: "hardcover", status: .stream),
      syncable(provider: "jellyfin", status: .stream),
    ])

    XCTAssertEqual(link?.providerName, "jellyfin")
  }

  /// A Hardcover-only book came from the cloud: no link to mark, and no upload to queue
  func testAFinishedDownloadOfAHardcoverOnlyBookPicksNoLink() {
    XCTAssertNil(SyncService.streamedMediaServerLink(in: [syncable(provider: "hardcover", status: .stream)]))
  }

  /// A link marked downloaded already has its file in the cloud
  func testAFinishedDownloadSkipsALinkAlreadyDownloaded() {
    XCTAssertNil(SyncService.streamedMediaServerLink(in: [syncable(provider: "jellyfin", status: .downloaded)]))
  }

  // MARK: - Helpers

  private struct LoadStopped: Error {}

  /// A loader whose playback service stops the load right after the missing-file check
  @MainActor
  private func makeLoader() -> PlayerLoaderService {
    let playbackService = PlaybackServiceProtocolMock()
    playbackService.getPlayableItemFromThrowableError = LoadStopped()
    let playerManager = PlayerManagerProtocolMock()
    playerManager.hasLoadedBookReturnValue = false

    let loader = PlayerLoaderService()
    // Never set up: sync is off
    loader.setup(
      syncService: SyncService(),
      libraryService: libraryService,
      playbackService: playbackService,
      playerManager: playerManager
    )
    return loader
  }

  private func missingBook(links: [SimpleExternalResource]? = nil) -> SimpleLibraryItem {
    SimpleLibraryItem(
      title: "Missing",
      details: "The Author",
      speed: 1,
      currentTime: 0,
      duration: 300,
      percentCompleted: 0,
      isFinished: false,
      relativePath: "missing-\(UUID().uuidString).m4b",
      remoteURL: nil,
      artworkURL: nil,
      orderRank: 0,
      parentFolder: nil,
      originalFileName: "missing.m4b",
      lastPlayDate: nil,
      type: .book,
      uuid: UUID().uuidString,
      externalResources: links
    )
  }

  private func syncable(provider: String, status: ExternalResource.SyncStatus) -> SyncableExternalResource {
    SyncableExternalResource(
      providerName: provider,
      providerId: "\(provider)-1",
      syncStatus: status.rawValue,
      lastSyncedAt: nil,
      processedFile: false,
      hostId: nil
    )
  }

  private func link(
    provider: String,
    status: ExternalResource.SyncStatus,
    item: SimpleLibraryItem? = nil
  ) -> SimpleExternalResource {
    SimpleExternalResource(
      providerName: provider,
      providerId: "\(provider)-1",
      syncStatus: status.rawValue,
      lastSyncedAt: nil,
      hostId: "https://media.example.com",
      libraryItem: item
    )
  }
}
