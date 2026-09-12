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

  /// The shell-row mapping: id carries the provider identity (removal is keyed on
  /// it), the title is the real filename, and a resource with no library item falls
  /// back to the unknown-title copy instead of rendering empty.
  func testConfirmationRowsMapIdentityFilenameAndFallback() {
    let named = SimpleExternalResource(
      providerName: "jellyfin",
      providerId: "row-1",
      syncStatus: ExternalResource.SyncStatus.stream.rawValue,
      lastSyncedAt: nil,
      libraryItem: SimpleLibraryItem(
        title: "Book",
        details: "Author",
        speed: 1.0,
        currentTime: 0,
        duration: 10,
        percentCompleted: 0,
        isFinished: false,
        relativePath: "row-1-book.m4b",
        remoteURL: nil,
        artworkURL: nil,
        orderRank: 0,
        parentFolder: nil,
        originalFileName: "book.m4b",
        lastPlayDate: nil,
        type: .book,
        uuid: "uuid-1"
      )
    )
    let orphan = SimpleExternalResource(
      providerName: "jellyfin",
      providerId: "row-2",
      syncStatus: ExternalResource.SyncStatus.stream.rawValue,
      lastSyncedAt: nil,
      libraryItem: nil
    )
    let sut = ExternalImportViewModel(
      batch: ExternalImportBatch(resources: [named, orphan]),
      onConfirm: { _ in }
    )

    let rows = sut.confirmationRows

    XCTAssertEqual(rows.map(\.id), ["row-1", "row-2"])
    XCTAssertEqual(rows.first?.title, "book.m4b")
    XCTAssertEqual(rows.last?.title, "voiceover_unknown_title".localized)
    XCTAssertEqual(rows.map(\.icon), ["waveform", "waveform"])
  }
}

// MARK: - Confirm destinations (bulk vs details)

@MainActor
final class ExternalImportConfirmDestinationTests: XCTestCase {
  private func makeResources() -> [SimpleExternalResource] {
    [SimpleExternalResource(
      providerName: "jellyfin",
      providerId: "confirm-1",
      syncStatus: ExternalResource.SyncStatus.stream.rawValue,
      lastSyncedAt: nil,
      libraryItem: nil
    )]
  }

  func testBulkConfirmSendsBatchThenDismissesBrowser() {
    var sent: [SimpleExternalResource]?
    var dismissed = false
    let navigation = BPNavigation()
    navigation.dismiss = { dismissed = true }

    let sut = JellyfinLibraryViewModel(
      folderID: "folder-1",
      connectionService: JellyfinConnectionService(),
      singleFileDownloadService: SingleFileDownloadService(networkClient: NetworkClient()),
      onImportConfirmed: { sent = $0 },
      accountService: AccountService(),
      navigation: navigation,
      navigationTitle: "Library"
    )

    sut.confirmExternalImport(makeResources())

    XCTAssertEqual(sent?.map(\.providerId), ["confirm-1"])
    XCTAssertTrue(dismissed, "bulk confirm closes the browser — the batch lands in the library")
  }

  func testDetailsConfirmSendsWithoutDismissing() {
    var sent: [SimpleExternalResource]?
    var dismissed = false
    let navigation = BPNavigation()
    navigation.dismiss = { dismissed = true }

    let sut = JellyfinAudiobookDetailsViewModel(
      item: JellyfinLibraryItem(id: "item-1", name: "Book", kind: .audiobook),
      connectionService: JellyfinConnectionService(),
      singleFileDownloadService: SingleFileDownloadService(networkClient: NetworkClient()),
      accountService: AccountService(),
      onImportConfirmed: { sent = $0 },
      navigation: navigation,
      navigationTitle: "Book"
    )

    sut.confirmExternalImport(makeResources())

    XCTAssertEqual(sent?.map(\.providerId), ["confirm-1"])
    XCTAssertFalse(dismissed, "details confirm keeps you in the browser for serial importing")
  }
}

// MARK: - AudiobookShelf payload decoding

@MainActor
final class AudiobookShelfDecodingTests: XCTestCase {
  /// Real-shaped expanded payload: the server's AudioFile.toJSON nests filename/ext
  /// under `metadata`, and `ext` arrives dot-prefixed (".m4b"). Pinned as a JSON
  /// fixture because the previous decoder expected top-level fields — it could never
  /// decode a live server response, and builder-based tests couldn't catch that.
  func testBatchGetPayloadDecodesNestedAudioFileMetadataAndStripsDot() throws {
    let json = Data("""
    {
      "libraryItems": [
        {
          "id": "li_1",
          "libraryId": "lib_1",
          "mediaType": "book",
          "media": {
            "metadata": { "title": "Real Book" },
            "audioFiles": [
              {
                "index": 1,
                "ino": "123",
                "metadata": {
                  "filename": "Real Book.m4b",
                  "ext": ".m4b",
                  "path": "/audiobooks/Real Book.m4b"
                },
                "addedAt": 1
              }
            ]
          }
        }
      ]
    }
    """.utf8)

    let decoded = try JSONDecoder().decode(AudiobookShelfBatchItemsResponse.self, from: json)
    let items = (decoded.libraryItems ?? []).compactMap { AudiobookShelfLibraryItem(apiItem: $0) }

    XCTAssertEqual(items.first?.fileExtension, "m4b", "nested metadata decodes; leading dot is stripped")
  }
}

// MARK: - External-resource host resolution

/// KeychainServiceProtocol has no generated mock (generic requirements); a local
/// dictionary-backed stub is enough for the resolver's read path.
private final class KeychainStub: KeychainServiceProtocol, @unchecked Sendable {
  let valueUpdatedPublisher = PassthroughSubject<KeychainUpdateValue, Never>()
  var storage: [KeychainKeys: Any] = [:]

  func set(_ value: String, key: KeychainKeys) throws { storage[key] = value }
  func set<T: Encodable>(_ value: T, key: KeychainKeys) throws { storage[key] = value }
  func get(_ key: KeychainKeys) throws -> String? { storage[key] as? String }
  func get<T: Decodable>(_ key: KeychainKeys) throws -> T? { storage[key] as? T }
  func remove(_ key: KeychainKeys) throws { storage[key] = nil }
}

final class ExternalResourceResolutionTests: XCTestCase {
  private func makeResource(provider: String, id: String, hostId: String?) -> SimpleExternalResource {
    SimpleExternalResource(
      providerName: provider,
      providerId: id,
      syncStatus: ExternalResource.SyncStatus.stream.rawValue,
      lastSyncedAt: nil,
      hostId: hostId,
      libraryItem: nil
    )
  }

  /// The pure resolver behind the details section: a hostId matching a saved
  /// connection (GUID, case-insensitive per IntegrationHostResolver) renders the
  /// server URL; an unknown host falls back to the raw hostId.
  func testResolvesSavedConnectionsAndFallsBackToRawHostId() throws {
    let keychain = KeychainStub()
    try keychain.set(
      [JellyfinConnectionData(
        serverId: "GUID-JELLY",
        url: URL(string: "https://jelly.example.com")!,
        serverName: "Jelly",
        userID: "u1",
        userName: "user",
        accessToken: "t"
      )],
      key: .jellyfinConnection
    )

    let resolved = IntegrationHostResolver.hostDisplayStrings(
      for: [
        makeResource(provider: "jellyfin", id: "r1", hostId: "guid-jelly"),
        makeResource(provider: "jellyfin", id: "r2", hostId: "unknown-guid"),
      ],
      keychain: keychain
    )

    XCTAssertEqual(resolved["r1"], "https://jelly.example.com", "GUID match is case-insensitive")
    XCTAssertEqual(resolved["r2"], "unknown-guid", "unknown host falls back to the raw hostId")
  }

  /// The section shows media-server links only: Hardcover has its own section, and
  /// repeating its link here would render a bare provider/id pair with no host. The rule
  /// allowlists known media servers, and its switch is exhaustive, so adding a provider
  /// is a compile error at the one place the question is answered.
  func testMediaServerResourcesKeepsOnlyKnownMediaServers() {
    let hosted = [
      makeResource(provider: "jellyfin", id: "r1", hostId: "guid-jelly"),
      makeResource(provider: "hardcover", id: "12345", hostId: nil),
      makeResource(provider: "audiobookshelf", id: "r2", hostId: "https://abs.example.com"),
      makeResource(provider: "somethingnew", id: "r3", hostId: "guid-new"),
    ].mediaServerResources

    XCTAssertEqual(
      hosted.map(\.providerId),
      ["r1", "r2"],
      "hardcover and unknown providers are both dropped — only known media servers stream"
    )
  }

  /// The streaming pick must ignore Hardcover links. They share the item's resource
  /// relationship and "hardcover" sorts between "audiobookshelf" and "jellyfin", so a
  /// hardcover row whose syncStatus came back from sync as anything but not_synced would
  /// otherwise win the pick and leave a streamable item with no external URL.
  func testStreamingResourceIgnoresHardcoverEvenWhenItSortsFirst() {
    let picked = [
      makeResource(provider: "hardcover", id: "12345", hostId: nil),
      makeResource(provider: "jellyfin", id: "r1", hostId: "guid-jelly"),
    ].streamingResource

    XCTAssertEqual(picked?.providerName, "jellyfin")
    XCTAssertEqual(picked?.providerId, "r1")
  }

  /// Two streaming providers on one item resolve to a stable pick across launches, since
  /// the underlying snapshot set is unordered.
  func testStreamingResourceIsDeterministicAcrossProviders() {
    let jellyfin = makeResource(provider: "jellyfin", id: "r1", hostId: "guid-jelly")
    let abs = makeResource(provider: "audiobookshelf", id: "r2", hostId: "guid-abs")

    XCTAssertEqual(
      [jellyfin, abs].streamingResource?.providerId,
      [abs, jellyfin].streamingResource?.providerId,
      "the pick must not depend on the order the set yields"
    )
  }

  func testStreamingResourceSkipsNotSyncedAndEmptyInput() {
    let notSynced = SimpleExternalResource(
      providerName: "jellyfin",
      providerId: "r1",
      syncStatus: ExternalResource.SyncStatus.notSynced.rawValue,
      lastSyncedAt: nil,
      hostId: "guid-jelly",
      libraryItem: nil
    )

    XCTAssertNil([notSynced].streamingResource)
    XCTAssertNil([SimpleExternalResource]().streamingResource)
  }

  /// A Hardcover-only item must render no external-resources section at all.
  func testMediaServerResourcesIsEmptyForHardcoverOnly() {
    XCTAssertTrue(
      [makeResource(provider: "hardcover", id: "12345", hostId: nil)].mediaServerResources.isEmpty
    )
    XCTAssertTrue([SimpleExternalResource]().mediaServerResources.isEmpty)
  }
}

/// The item-side half of the "Media Servers" button rule on a playback-failure alert.
/// The entitlement half is exercised against a real PlayerManager in PlayerManagerTests.
final class MediaServersShortcutTests: XCTestCase {
  private func makeChapter(externalUrl: URL?, hasUnresolvedExternalHost: Bool) -> PlayableChapter {
    PlayableChapter(
      title: "Chapter",
      author: "Author",
      start: 0,
      duration: 100,
      relativePath: "missing-book.m4b",
      remoteURL: URL(string: "https://s3.example.com/presigned"),
      externalURL: externalUrl,
      index: 1,
      hasUnresolvedExternalHost: hasUnresolvedExternalHost
    )
  }

  /// The case the old condition got wrong: on a device where the item's media server was
  /// never added, nothing resolves the host, so there is no external URL — but the API
  /// still hands back a presigned remoteURL, which is what used to suppress the button.
  func testNeedsMediaServerWhenTheServerIsNotConfiguredOnThisDevice() {
    XCTAssertTrue(
      makeChapter(externalUrl: nil, hasUnresolvedExternalHost: true).needsMediaServer()
    )
  }

  func testNeedsMediaServerWhenTheStreamItselfFailed() {
    XCTAssertTrue(
      makeChapter(
        externalUrl: URL(string: "https://jelly.example.com/stream"),
        hasUnresolvedExternalHost: false
      ).needsMediaServer()
    )
  }

  /// A plain local file that went missing has nothing to do with a media server.
  func testDoesNotNeedMediaServerWithoutAMediaServerResource() {
    XCTAssertFalse(
      makeChapter(externalUrl: nil, hasUnresolvedExternalHost: false).needsMediaServer()
    )
  }

  /// The file is on disk, so whatever failed, a missing server isn't it.
  func testDoesNotNeedMediaServerWhenTheFileExists() throws {
    let folder = DataManager.getProcessedFolderURL()
    let onDisk = folder.appendingPathComponent("present-book.m4b")
    try Data("audio".utf8).write(to: onDisk)
    defer { try? FileManager.default.removeItem(at: onDisk) }

    let chapter = PlayableChapter(
      title: "Chapter",
      author: "Author",
      start: 0,
      duration: 100,
      relativePath: "present-book.m4b",
      remoteURL: nil,
      externalURL: nil,
      index: 1,
      hasUnresolvedExternalHost: true
    )

    XCTAssertFalse(chapter.needsMediaServer())
  }
}

/// Construction-time work moved out of `ItemDetailsViewModel.init` into `load()`, which is
/// what makes the view model constructible in a test at all: `init` no longer starts an
/// unstructured task that reaches the network.
@MainActor
final class ItemDetailsLoadTests: XCTestCase {
  /// HardcoverServiceProtocol isn't AutoMockable, and its seven members are few enough to
  /// stub by hand rather than pull Sourcery into the change.
  private final class HardcoverServiceStub: HardcoverServiceProtocol {
    var authorization: String?
    var getBookCallCount = 0
    var bookToReturn: SimpleHardcoverBook?

    func getBook(id: Int) async throws -> SimpleHardcoverBook? {
      getBookCallCount += 1
      return bookToReturn
    }

    func getBooks(for item: SimpleLibraryItem, perPage: Int) async throws -> BooksData {
      throw BookPlayerError.runtimeError("not used")
    }
    func searchBooks(query: String, perPage: Int) async throws -> BooksData {
      throw BookPlayerError.runtimeError("not used")
    }
    func processAutoMatch(for items: [SimpleLibraryItem]) async {}
    func assignItem(_ book: SimpleHardcoverBook?, to item: SimpleLibraryItem) async {}
    func removeFromLibrary(_ book: SimpleHardcoverBook) async throws {}
  }

  private func makeSUT() -> (ItemDetailsViewModel, LibraryServiceProtocolMock, HardcoverServiceStub) {
    let hardcoverResource = SimpleExternalResource(
      providerName: ExternalResource.ProviderName.hardcover.rawValue,
      providerId: "12345",
      syncStatus: ExternalResource.SyncStatus.stream.rawValue,
      lastSyncedAt: nil,
      libraryItem: nil
    )
    let item = SimpleLibraryItem(
      title: "Local Title",
      details: "Local Author",
      speed: 1,
      currentTime: 0,
      duration: 100,
      percentCompleted: 0,
      isFinished: false,
      relativePath: "book.m4b",
      remoteURL: nil,
      artworkURL: nil,
      orderRank: 0,
      parentFolder: nil,
      originalFileName: "book.m4b",
      lastPlayDate: nil,
      type: .book,
      uuid: "UUID",
      externalResources: [hardcoverResource]
    )

    let libraryService = LibraryServiceProtocolMock()
    // No local Hardcover row on this device: the synced-down link is all we have, which is
    // the path that fetches.
    libraryService.getHardcoverBookForReturnValue = nil
    libraryService.getExternalResourcesForReturnValue = [hardcoverResource]

    let hardcoverService = HardcoverServiceStub()
    // ItemDetailsHardcoverSectionViewModel.init? returns nil without a token, and the whole
    // hardcover resolve path is gated on that section existing — so an unconnected account
    // resolves nothing, by design.
    hardcoverService.authorization = "test-token"
    hardcoverService.bookToReturn = SimpleHardcoverBook(
      id: 12345,
      artworkURL: nil,
      title: "Fetched Title",
      author: "Fetched Author",
      status: .reading
    )

    let sut = ItemDetailsViewModel(
      item: item,
      libraryService: libraryService,
      syncService: SyncServiceProtocolMock(),
      hardcoverService: hardcoverService,
      listState: ListStateManager()
    )

    return (sut, libraryService, hardcoverService)
  }

  /// The regression this guards: `.task` fires again whenever the view re-appears, and the
  /// load must not refetch (or re-clobber the picker selection) when it does.
  func testLoadRunsOnlyOnceAcrossRepeatedCalls() async {
    let (sut, libraryService, hardcoverService) = makeSUT()

    await sut.load()
    await sut.load()
    await sut.load()

    XCTAssertEqual(hardcoverService.getBookCallCount, 1, "a re-appear must not refetch")
    XCTAssertEqual(libraryService.getHardcoverBookForCallsCount, 1)
  }

  /// Behavior that had no coverage before, because the view model couldn't be constructed:
  /// with no local row, the picker is seeded from the synced resource and then upgraded to
  /// the metadata Hardcover returns.
  func testLoadResolvesTheSelectionFromASyncedResource() async {
    let (sut, _, _) = makeSUT()

    XCTAssertNil(sut.hardcoverSectionViewModel?.pickerViewModel.selected)

    await sut.load()

    let selected = sut.hardcoverSectionViewModel?.pickerViewModel.selected
    XCTAssertEqual(selected?.id, 12345)
    XCTAssertEqual(selected?.title, "Fetched Title", "the interim title upgrades to the fetch")
    XCTAssertEqual(sut.hardcoverSectionViewModel?.isFetchingBook, false, "spinner is cleared")
  }

  /// Nothing is fetched off the main path during construction any more.
  func testInitDoesNotResolveAnything() {
    let (sut, libraryService, hardcoverService) = makeSUT()

    XCTAssertEqual(hardcoverService.getBookCallCount, 0)
    XCTAssertEqual(libraryService.getHardcoverBookForCallsCount, 0)
    XCTAssertTrue(sut.resolvedExternalHosts.isEmpty)
  }
}

// MARK: - External progress pull

/// The inbound half of media-server progress sync, extracted out of ItemListViewModel.
///
/// Waits are expectations fulfilled by the publisher, never fixed sleeps: the service's timing
/// is what's under test, and a fixed wait either flakes on a slow runner or hides a real
/// delay. Notifications go through a private center so nothing here can reach a real
/// service alive elsewhere in the test process.
@MainActor
final class ExternalProgressServiceTests: XCTestCase {
  /// Records what it was asked and answers from a script, so a test can assert the fan-out
  /// without a server, a keychain, or a network. A slow answer sleeps WITHOUT swallowing
  /// cancellation, so a cancelled refresh provably reaches the provider.
  private final class ProviderStub: ExternalProgressProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var _requested: [String] = []
    private let answer: @Sendable (SimpleExternalResource) async throws -> ExternalPlaybackProgress?

    var requested: [String] {
      lock.lock()
      defer { lock.unlock() }
      return _requested
    }

    init(answer: @escaping @Sendable (SimpleExternalResource) async throws -> ExternalPlaybackProgress?) {
      self.answer = answer
    }

    func progress(for resource: SimpleExternalResource) async throws -> ExternalPlaybackProgress? {
      lock.lock()
      _requested.append(resource.providerId)
      lock.unlock()
      return try await answer(resource)
    }

    func progress(
      forBatch resources: [SimpleExternalResource]
    ) async throws -> [String: ExternalPlaybackProgress] {
      var out: [String: ExternalPlaybackProgress] = [:]
      for resource in resources {
        if let progress = try await progress(for: resource) {
          out[resource.providerId] = progress
        }
      }
      return out
    }
  }

  private var notificationCenter: NotificationCenter!
  private var received: [ExternalPlaybackProgress] = []
  private var cancellable: AnyCancellable?

  override func setUp() {
    super.setUp()
    notificationCenter = NotificationCenter()
    received = []
  }

  override func tearDown() {
    cancellable?.cancel()
    cancellable = nil
    super.tearDown()
  }

  private func makeResource(provider: String, id: String) -> SimpleExternalResource {
    SimpleExternalResource(
      providerName: provider,
      providerId: id,
      syncStatus: ExternalResource.SyncStatus.stream.rawValue,
      lastSyncedAt: nil,
      hostId: "guid-host",
      libraryItem: nil
    )
  }

  private func makeLibraryItem(resources: [SimpleExternalResource]?) -> SimpleLibraryItem {
    SimpleLibraryItem(
      title: "Book",
      details: "Author",
      speed: 1,
      currentTime: 0,
      duration: 1000,
      percentCompleted: 0,
      isFinished: false,
      relativePath: "book-\(resources?.first?.providerId ?? "none").m4b",
      remoteURL: nil,
      artworkURL: nil,
      orderRank: 0,
      parentFolder: nil,
      originalFileName: "book.m4b",
      lastPlayDate: nil,
      type: .book,
      uuid: "UUID-\(resources?.first?.providerId ?? "none")",
      externalResources: resources
    )
  }

  private func makeItem(uuid: String, currentTime: TimeInterval, lastPlayDate: Date?) -> PlayableItem {
    PlayableItem(
      title: "Book",
      author: "Author",
      chapters: [
        PlayableChapter(
          title: "Chapter",
          author: "Author",
          start: 0,
          duration: 1000,
          relativePath: "book.m4b",
          remoteURL: nil,
          externalURL: nil,
          index: 1
        )
      ],
      currentTime: currentTime,
      duration: 1000,
      relativePath: "book.m4b",
      uuid: uuid,
      parentFolder: nil,
      percentCompleted: 0,
      lastPlayDate: lastPlayDate,
      isFinished: false,
      isBoundBook: false
    )
  }

  private func makeSUT(
    resources: [SimpleExternalResource],
    providers: [ExternalResource.ProviderName: ExternalProgressProviding]
  ) -> (ExternalProgressService, LibraryServiceProtocolMock) {
    let libraryService = LibraryServiceProtocolMock()
    libraryService.findResourcesForReturnValue = resources

    let sut = ExternalProgressService()
    sut.setup(libraryService: libraryService, providers: providers, notificationCenter: notificationCenter)
    return (sut, libraryService)
  }

  /// Subscribes and returns an expectation that fulfils once per published position.
  private func expectPublish(from sut: ExternalProgressService, count: Int = 1, inverted: Bool = false) -> XCTestExpectation {
    let expectation = expectation(description: inverted ? "nothing published" : "position published")
    expectation.isInverted = inverted
    if !inverted {
      expectation.expectedFulfillmentCount = count
      expectation.assertForOverFulfill = true
    }
    cancellable = sut.promptablePositionPublisher
      .receive(on: DispatchQueue.main)
      .sink { [weak self] position in
        self?.received.append(position)
        expectation.fulfill()
      }
    return expectation
  }

  private func slowStub(_ progress: ExternalPlaybackProgress) -> ProviderStub {
    ProviderStub { _ in
      try await Task.sleep(nanoseconds: 250_000_000)
      return progress
    }
  }

  // MARK: the decision rule

  func testPromptsWhenTheRemoteDateIsNewerBeyondTheThreshold() {
    let position = [ExternalPlaybackProgress(currentTime: 90, lastPlayedDate: Date(timeIntervalSince1970: 1100))]
      .promptable(localTime: 100, localDate: Date(timeIntervalSince1970: 1000))

    XCTAssertEqual(position?.currentTime, 90, "a newer date prompts even when the position is behind")
  }

  func testDoesNotPromptInsideTheThreshold() {
    let position = [ExternalPlaybackProgress(currentTime: 110, lastPlayedDate: Date(timeIntervalSince1970: 1005))]
      .promptable(localTime: 100, localDate: Date(timeIntervalSince1970: 1000))

    XCTAssertNil(position, "10s of drift on the book you are listening to is not another device")
  }

  func testPromptsWhenTheRemotePositionIsFartherWithoutADate() {
    let position = [ExternalPlaybackProgress(currentTime: 400, lastPlayedDate: nil)]
      .promptable(localTime: 100, localDate: Date(timeIntervalSince1970: 1000))

    XCTAssertEqual(position?.currentTime, 400, "a server reporting no date still counts on position")
  }

  /// The rule SyncService.handleSyncedLastPlayed uses for our own cloud: newest date wins.
  func testNewestCandidateWinsAcrossServers() {
    let older = ExternalPlaybackProgress(currentTime: 900, lastPlayedDate: Date(timeIntervalSince1970: 1100))
    let newer = ExternalPlaybackProgress(currentTime: 300, lastPlayedDate: Date(timeIntervalSince1970: 2000))

    let position = [older, newer]
      .promptable(localTime: 100, localDate: Date(timeIntervalSince1970: 1000))

    XCTAssertEqual(position, newer, "the most recently played server wins, not the farthest position")
  }

  func testNoCandidatesMeansNoPrompt() {
    XCTAssertNil(
      [ExternalPlaybackProgress]().promptable(localTime: 100, localDate: nil)
    )
  }

  // MARK: the service

  func testAsksEveryLinkedServerConcurrentlyAndPublishesTheNewest() async {
    let jellyfin = ProviderStub { _ in
      ExternalPlaybackProgress(currentTime: 800, lastPlayedDate: Date(timeIntervalSince1970: 1100))
    }
    let abs = ProviderStub { _ in
      ExternalPlaybackProgress(currentTime: 200, lastPlayedDate: Date(timeIntervalSince1970: 5000))
    }
    let (sut, _) = makeSUT(
      resources: [makeResource(provider: "jellyfin", id: "jf-1"), makeResource(provider: "audiobookshelf", id: "abs-1")],
      providers: [.jellyfin: jellyfin, .audiobookshelf: abs]
    )
    let published = expectPublish(from: sut)

    sut.refreshProgress(for: makeItem(uuid: "UUID", currentTime: 100, lastPlayDate: Date(timeIntervalSince1970: 1000)))
    await fulfillment(of: [published], timeout: 2)

    XCTAssertEqual(jellyfin.requested, ["jf-1"], "both servers are asked")
    XCTAssertEqual(abs.requested, ["abs-1"])
    XCTAssertEqual(received.map(\.currentTime), [200], "the newest date wins across providers")
  }

  func testOneFailingServerDoesNotSilenceTheOther() async {
    let failing = ProviderStub { _ in throw URLError(.timedOut) }
    let working = ProviderStub { _ in
      ExternalPlaybackProgress(currentTime: 700, lastPlayedDate: Date(timeIntervalSince1970: 9000))
    }
    let (sut, _) = makeSUT(
      resources: [makeResource(provider: "jellyfin", id: "jf-1"), makeResource(provider: "audiobookshelf", id: "abs-1")],
      providers: [.jellyfin: failing, .audiobookshelf: working]
    )
    let published = expectPublish(from: sut)

    sut.refreshProgress(for: makeItem(uuid: "UUID", currentTime: 0, lastPlayDate: nil))
    await fulfillment(of: [published], timeout: 2)

    XCTAssertEqual(received.map(\.currentTime), [700], "a thrown error takes out only its own provider")
  }

  /// Hardcover shares the resource relationship but hosts nothing, so it must never be asked.
  func testSkipsResourcesWithNoMediaServerProvider() async {
    let jellyfin = ProviderStub { _ in XCTFail("hardcover must not reach a provider"); return nil }
    let (sut, _) = makeSUT(
      resources: [makeResource(provider: "hardcover", id: "12345")],
      providers: [.jellyfin: jellyfin]
    )
    let nothing = expectPublish(from: sut, inverted: true)

    sut.refreshProgress(for: makeItem(uuid: "UUID", currentTime: 0, lastPlayDate: nil))
    await fulfillment(of: [nothing], timeout: 0.3)

    XCTAssertTrue(jellyfin.requested.isEmpty)
  }

  /// The bug that started the extraction: a slow answer for a book the user already left
  /// must not raise a prompt carrying that book's position. With cancellation propagating
  /// into the stub, the superseded refresh never even completes.
  func testAnswerForASupersededItemIsDiscarded() async {
    let slow = slowStub(ExternalPlaybackProgress(currentTime: 900, lastPlayedDate: Date(timeIntervalSince1970: 9000)))
    let (sut, _) = makeSUT(
      resources: [makeResource(provider: "jellyfin", id: "jf-1")],
      providers: [.jellyfin: slow]
    )
    let published = expectPublish(from: sut, count: 1)

    sut.refreshProgress(for: makeItem(uuid: "FIRST", currentTime: 0, lastPlayDate: nil))
    // A different book starts before the first answer lands.
    sut.refreshProgress(for: makeItem(uuid: "SECOND", currentTime: 0, lastPlayDate: nil))
    await fulfillment(of: [published], timeout: 2)

    XCTAssertEqual(received.count, 1, "only the item that is playing now can prompt")
    XCTAssertEqual(slow.requested, ["jf-1", "jf-1"], "both refreshes reached the provider; only one survived")
  }

  /// The point of the extraction: the pull is driven by the notification the player posts for
  /// EVERY playback start, so it no longer depends on which UI holds a delegate slot.
  func testRefreshesFromTheBookPlayedNotification() async {
    let jellyfin = ProviderStub { _ in
      ExternalPlaybackProgress(currentTime: 600, lastPlayedDate: Date(timeIntervalSince1970: 9000))
    }
    let (sut, _) = makeSUT(
      resources: [makeResource(provider: "jellyfin", id: "jf-1")],
      providers: [.jellyfin: jellyfin]
    )
    let published = expectPublish(from: sut)

    notificationCenter.post(
      name: .bookPlayed,
      object: nil,
      userInfo: ["book": makeItem(uuid: "UUID", currentTime: 0, lastPlayDate: nil)]
    )
    await fulfillment(of: [published], timeout: 2)

    XCTAssertEqual(jellyfin.requested, ["jf-1"], "playback start alone drives the pull")
    XCTAssertEqual(received.map(\.currentTime), [600])
  }

  func testLogoutNotificationCancelsInFlightWork() async {
    let slow = slowStub(ExternalPlaybackProgress(currentTime: 900, lastPlayedDate: Date(timeIntervalSince1970: 9000)))
    let (sut, _) = makeSUT(
      resources: [makeResource(provider: "jellyfin", id: "jf-1")],
      providers: [.jellyfin: slow]
    )
    let nothing = expectPublish(from: sut, inverted: true)

    sut.refreshProgress(for: makeItem(uuid: "UUID", currentTime: 0, lastPlayDate: nil))
    notificationCenter.post(name: .logout, object: nil)
    // Longer than the stub's sleep, so an un-cancelled refresh WOULD have published by now.
    await fulfillment(of: [nothing], timeout: 0.6)
  }

  func testTeardownCancelsAnInFlightRefresh() async {
    let slow = slowStub(ExternalPlaybackProgress(currentTime: 900, lastPlayedDate: Date(timeIntervalSince1970: 9000)))
    let (sut, _) = makeSUT(
      resources: [makeResource(provider: "jellyfin", id: "jf-1")],
      providers: [.jellyfin: slow]
    )
    let nothing = expectPublish(from: sut, inverted: true)

    sut.refreshProgress(for: makeItem(uuid: "UUID", currentTime: 0, lastPlayDate: nil))
    sut.teardown()
    await fulfillment(of: [nothing], timeout: 0.6)
  }

  // MARK: the list refresh

  /// The gap this closes: the list refresh collected Jellyfin resources only and handed them
  /// to an ingest typed to a Jellyfin item, so AudiobookShelf items were never refreshed.
  func testRefreshItemsFoldsInBothProviders() async {
    let jellyfin = ProviderStub { _ in
      ExternalPlaybackProgress(currentTime: 120, lastPlayedDate: Date(timeIntervalSince1970: 500))
    }
    let abs = ProviderStub { _ in
      ExternalPlaybackProgress(currentTime: 340, lastPlayedDate: Date(timeIntervalSince1970: 900))
    }
    let (sut, libraryService) = makeSUT(resources: [], providers: [.jellyfin: jellyfin, .audiobookshelf: abs])

    await sut.refreshItems([
      makeLibraryItem(resources: [makeResource(provider: "jellyfin", id: "jf-1")]),
      makeLibraryItem(resources: [makeResource(provider: "audiobookshelf", id: "abs-1")]),
      makeLibraryItem(resources: [makeResource(provider: "hardcover", id: "12345")]),
    ])

    XCTAssertEqual(jellyfin.requested, ["jf-1"])
    XCTAssertEqual(abs.requested, ["abs-1"], "AudiobookShelf items refresh too")

    let ingested = libraryService.handleSyncFromExternalResourceProviderNameProgressByProviderIdReceivedInvocations
    XCTAssertEqual(
      Set(ingested.map(\.providerName)),
      ["jellyfin", "audiobookshelf"],
      "each provider folds its own answers in, under its own provider name"
    )
    XCTAssertFalse(
      ingested.contains { $0.providerName == "hardcover" },
      "hardcover hosts nothing, so it is never batched"
    )
  }

  func testRefreshItemsDoesNothingWithoutMediaServerResources() async {
    let jellyfin = ProviderStub { _ in XCTFail("must not be asked"); return nil }
    let (sut, libraryService) = makeSUT(resources: [], providers: [.jellyfin: jellyfin])

    await sut.refreshItems([makeLibraryItem(resources: nil)])

    XCTAssertTrue(jellyfin.requested.isEmpty)
    XCTAssertEqual(libraryService.handleSyncFromExternalResourceProviderNameProgressByProviderIdCallsCount, 0)
  }
}

// MARK: - External stream resolution

/// Stream URLs, auth headers and the unresolved-host flag. None of this could be tested while
/// the logic sat inside PlaybackService.getPlayableChapters with its own KeychainService().
final class ExternalStreamResolverTests: XCTestCase {
  private func makeResource(provider: String, id: String, hostId: String?) -> SimpleExternalResource {
    SimpleExternalResource(
      providerName: provider,
      providerId: id,
      syncStatus: ExternalResource.SyncStatus.stream.rawValue,
      lastSyncedAt: nil,
      hostId: hostId,
      libraryItem: nil
    )
  }

  private func makeKeychain(customHeaders: [String: String] = [:]) throws -> KeychainStub {
    let keychain = KeychainStub()
    try keychain.set(
      [
        JellyfinConnectionData(
          serverId: "GUID-JELLY",
          url: URL(string: "https://jelly.example.com")!,
          serverName: "Jelly",
          userID: "u1",
          userName: "user",
          accessToken: "jelly-token",
          customHeaders: customHeaders
        )
      ],
      key: .jellyfinConnection
    )
    return keychain
  }

  func testResolvesTheResourcesOwnServerWithItsAuthHeader() throws {
    let sut = ExternalStreamResolver(keychain: try makeKeychain())

    let source = sut.streamSource(for: makeResource(provider: "jellyfin", id: "item-1", hostId: "guid-jelly"))

    XCTAssertEqual(source?.url.host, "jelly.example.com")
    XCTAssertEqual(
      source?.headers["Authorization"],
      "MediaBrowser Token=\"jelly-token\"",
      "the integration's own token authorises the stream, never the BookPlayer JWT"
    )
  }

  /// The contract shared with the Android app: an unmatched host resolves to nothing rather
  /// than streaming from whichever server happens to be configured.
  func testDoesNotFallBackToAnotherServer() throws {
    let sut = ExternalStreamResolver(keychain: try makeKeychain())

    XCTAssertNil(
      sut.streamSource(for: makeResource(provider: "jellyfin", id: "item-1", hostId: "guid-somewhere-else"))
    )
  }

  /// Custom headers exist for reverse-proxy gates; the integration's Authorization must win,
  /// and a lowercase user-configured key must not fight it.
  func testIntegrationAuthorizationWinsOverACustomHeader() throws {
    let keychain = try makeKeychain(customHeaders: [
      "CF-Access-Client-Id": "cf-id",
      "authorization": "Bearer user-configured",
    ])
    let sut = ExternalStreamResolver(keychain: keychain)

    let source = sut.streamSource(for: makeResource(provider: "jellyfin", id: "item-1", hostId: "guid-jelly"))

    XCTAssertEqual(source?.headers["CF-Access-Client-Id"], "cf-id", "proxy gates survive")
    XCTAssertEqual(source?.headers["Authorization"], "MediaBrowser Token=\"jelly-token\"")
    XCTAssertEqual(
      source?.headers.filter { $0.key.caseInsensitiveCompare("Authorization") == .orderedSame }.count,
      1,
      "one Authorization header, not two spellings of it"
    )
  }

  func testHardcoverStreamsFromNowhere() throws {
    let sut = ExternalStreamResolver(keychain: try makeKeychain())

    XCTAssertNil(sut.streamSource(for: makeResource(provider: "hardcover", id: "12345", hostId: nil)))
  }
}

/// The flag PlaybackService puts on every chapter, now reachable because resolution is injected.
final class PlayableChapterExternalHostTests: XCTestCase {
  private struct ResolverStub: ExternalStreamResolving {
    let source: ExternalStreamSource?
    func streamSource(for resource: SimpleExternalResource) -> ExternalStreamSource? { source }
  }

  private func makeItem(resources: [SimpleExternalResource]?) -> SimpleLibraryItem {
    SimpleLibraryItem(
      title: "Book",
      details: "Author",
      speed: 1,
      currentTime: 0,
      duration: 100,
      percentCompleted: 0,
      isFinished: false,
      relativePath: "book.m4b",
      remoteURL: nil,
      artworkURL: nil,
      orderRank: 0,
      parentFolder: nil,
      originalFileName: "book.m4b",
      lastPlayDate: nil,
      type: .book,
      uuid: "UUID",
      externalResources: resources
    )
  }

  private func makeSUT(resolved: Bool) -> PlaybackService {
    let libraryService = LibraryServiceProtocolMock()
    libraryService.getChaptersFromReturnValue = [
      SimpleChapter(title: "Chapter", start: 0, duration: 100, index: 1)
    ]

    let sut = PlaybackService()
    sut.setup(
      libraryService: libraryService,
      streamResolver: ResolverStub(
        source: resolved
          ? ExternalStreamSource(
            url: URL(string: "https://jelly.example.com/stream")!,
            headers: ["Authorization": "MediaBrowser Token=\"t\""]
          )
          : nil
      )
    )
    return sut
  }

  private func mediaServerResource() -> SimpleExternalResource {
    SimpleExternalResource(
      providerName: "jellyfin",
      providerId: "item-1",
      syncStatus: ExternalResource.SyncStatus.stream.rawValue,
      lastSyncedAt: nil,
      hostId: "guid-jelly",
      libraryItem: nil
    )
  }

  func testResolvedResourceCarriesTheStreamUrlAndNoUnresolvedFlag() throws {
    let chapters = try makeSUT(resolved: true).getPlayableChapters(book: makeItem(resources: [mediaServerResource()]))

    XCTAssertEqual(chapters.first?.externalUrl?.host, "jelly.example.com")
    XCTAssertEqual(chapters.first?.externalHeaders["Authorization"], "MediaBrowser Token=\"t\"")
    XCTAssertFalse(chapters.first?.hasUnresolvedExternalHost ?? true)
  }

  /// The case the Media Servers shortcut depends on: a media-server item whose host resolves
  /// to nothing on this device.
  func testUnresolvedHostSetsTheFlagWithNoStreamUrl() throws {
    let chapters = try makeSUT(resolved: false).getPlayableChapters(book: makeItem(resources: [mediaServerResource()]))

    XCTAssertNil(chapters.first?.externalUrl)
    XCTAssertTrue(chapters.first?.hasUnresolvedExternalHost ?? false)
  }

  /// A plain local book has no media server, so a missing file is not a server problem.
  func testItemWithoutResourcesNeverSetsTheFlag() throws {
    let chapters = try makeSUT(resolved: false).getPlayableChapters(book: makeItem(resources: nil))

    XCTAssertNil(chapters.first?.externalUrl)
    XCTAssertFalse(chapters.first?.hasUnresolvedExternalHost ?? true)
  }
}

// MARK: - Resume offer routing

/// One surface asks, never two: the arbiter is the single subscriber to the service.
@MainActor
final class ResumeOfferArbiterTests: XCTestCase {
  private final class PresenterSpy: ResumeOfferPresenting {
    var presentedTimes: [TimeInterval] = []
    func presentResumeOffer(at remoteTime: TimeInterval) { presentedTimes.append(remoteTime) }
  }

  private let position = ExternalPlaybackProgress(currentTime: 480, lastPlayedDate: Date())

  func testWithoutCarPlayThePhoneGetsTheOffer() {
    let playerState = PlayerState()
    let sut = ResumeOfferArbiter(playerState: playerState, isAppActive: { false })

    sut.route(position)

    XCTAssertTrue(playerState.showResumePopup)
    XCTAssertEqual(playerState.remotePlayTime, 480)
  }

  /// The driving case: phone in a pocket, car connected. The car asks and the phone's flag is
  /// never raised, so unlocking the phone later cannot ask the same question again.
  func testCarPlayGetsTheOfferWhenTheAppIsInactive() {
    let playerState = PlayerState()
    let car = PresenterSpy()
    let sut = ResumeOfferArbiter(playerState: playerState, isAppActive: { false })
    sut.carPlayPresenter = car

    sut.route(position)

    XCTAssertEqual(car.presentedTimes, [480])
    XCTAssertFalse(playerState.showResumePopup, "an offer routed to the car leaves no phone flag behind")
    XCTAssertNil(playerState.remotePlayTime)
  }

  /// Phone in hand with the car connected: the SwiftUI alert is the better surface, and the
  /// car must stay quiet rather than ask in parallel.
  func testThePhoneWinsWhenTheAppIsActiveEvenWithCarPlayConnected() {
    let playerState = PlayerState()
    let car = PresenterSpy()
    let sut = ResumeOfferArbiter(playerState: playerState, isAppActive: { true })
    sut.carPlayPresenter = car

    sut.route(position)

    XCTAssertTrue(car.presentedTimes.isEmpty)
    XCTAssertTrue(playerState.showResumePopup)
  }

  func testAnOfferAlreadyShowingIsNotClobbered() {
    let playerState = PlayerState()
    playerState.showResumePopup = true
    playerState.remotePlayTime = 120
    let sut = ResumeOfferArbiter(playerState: playerState, isAppActive: { true })

    sut.route(position)

    XCTAssertEqual(playerState.remotePlayTime, 120, "the prompt the user is looking at keeps its position")
  }

  /// Disconnecting the car must hand the next offer back to the phone.
  func testAReleasedPresenterFallsBackToThePhone() {
    let playerState = PlayerState()
    let sut = ResumeOfferArbiter(playerState: playerState, isAppActive: { false })
    var car: PresenterSpy? = PresenterSpy()
    sut.carPlayPresenter = car
    car = nil

    sut.route(position)

    XCTAssertTrue(playerState.showResumePopup, "a weak presenter that went away is the same as none")
  }
}
