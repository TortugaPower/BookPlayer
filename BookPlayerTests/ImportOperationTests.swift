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
