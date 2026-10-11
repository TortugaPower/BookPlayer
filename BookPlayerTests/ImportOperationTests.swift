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

  private func hydrated(_ fileExtension: String, duration: TimeInterval = 4800) -> HydratedItem? {
    HydratedItem(fileExtension: fileExtension, duration: duration)
  }

  func testBuildsOnlyHydratedItemsInSelectionOrder() async throws {
    let items = [StubItem(id: "a"), StubItem(id: "b"), StubItem(id: "c")]
    let resources = try await VirtualImportPipeline.run(
      items: items,
      id: \.id,
      hydrate: { ids in
        XCTAssertEqual(ids, ["a", "b", "c"])
        var hydratedByID: [String: HydratedItem] = [:]
        hydratedByID["a"] = self.hydrated("m4b")
        hydratedByID["c"] = self.hydrated("mp3")
        return hydratedByID  // "b" reports no audio-file metadata
      },
      buildResource: { item, _ in self.makeResource(id: item.id) }
    )
    XCTAssertEqual(resources.map(\.providerId), ["a", "c"], "skips unhydrated items, keeps selection order")
  }

  /// Drives the drop through the REAL provider mapping rather than a stub, so it fails if a
  /// closure ever starts reading a source that reports "unmeasured" as something other than nil.
  func testSkipsItemsTheServerNeverMeasured() async throws {
    let measured = AudiobookShelfLibraryItem(
      id: "measured",
      title: "Measured",
      kind: .audiobook,
      libraryId: "lib",
      duration: 4800,
      fileExtension: "m4b"
    )
    let unmeasured = AudiobookShelfLibraryItem(
      id: "unmeasured",
      title: "Unmeasured",
      kind: .audiobook,
      libraryId: "lib",
      duration: nil,
      fileExtension: "m4b"
    )

    let resources = try await VirtualImportPipeline.run(
      items: [measured, unmeasured],
      id: \.id,
      hydrate: { _ in
        [measured, unmeasured].reduce(into: [:]) {
          $0[$1.id] = HydratedItem(fileExtension: $1.fileExtension, duration: $1.duration)
        }
      },
      buildResource: { item, _ in self.makeResource(id: item.id) }
    )

    XCTAssertEqual(
      resources.map(\.providerId),
      ["measured"],
      "an item with no server-measured length would import a row that can never play"
    )
  }

  func testHydratedItemRequiresARealExtensionAndAMeasuredLength() {
    XCTAssertNotNil(HydratedItem(fileExtension: "m4b", duration: 1))

    XCTAssertNil(HydratedItem(fileExtension: nil, duration: 4800))
    XCTAssertNil(HydratedItem(fileExtension: "", duration: 4800))
    XCTAssertNil(HydratedItem(fileExtension: "m4b", duration: nil))
    /// Jellyfin's mapper collapses an unprobed runtime to 0 rather than nil, so the
    /// gate has to be `> 0`, not `!= nil`
    XCTAssertNil(HydratedItem(fileExtension: "m4b", duration: 0))
    XCTAssertNil(HydratedItem(fileExtension: "m4b", duration: -1))
  }

  func testEmptySelectionNeverHydrates() async throws {
    var hydrateCalled = false
    let resources = try await VirtualImportPipeline.run(
      items: [StubItem](),
      id: \.id,
      hydrate: { _ in
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
        hydrate: { _ in throw URLError(.notConnectedToInternet) },
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

  /// Like the bulk confirm: the library can only show where to put the batch once the
  /// browser is closed (an alert set beneath it is dropped and blocks every later one).
  func testDetailsConfirmSendsBatchThenDismissesBrowser() {
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
    XCTAssertTrue(dismissed, "details confirm closes the browser, as the bulk one does")
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
            "duration": 4800,
            "chapters": [
              { "start": 0, "end": 600, "title": "Chapter One" },
              { "start": 600, "end": 4800, "title": "Chapter Two" }
            ],
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
    XCTAssertEqual(
      items.first?.duration,
      4800,
      "the virtual import refuses an item without a length, so the batch payload has to carry one"
    )
    XCTAssertEqual(
      items.first?.chapters.map(\.title),
      ["Chapter One", "Chapter Two"],
      "batch/get returns EXPANDED media, so chapters arrive on the same response as audioFiles"
    )
    XCTAssertEqual(items.first?.chapters.map(\.duration), [600, 4200])
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

  /// Pins the `.audiobookshelf` arm, which nothing else does.
  /// `testResolvesSavedConnectionsAndFallsBackToRawHostId` above catches a wrong `.jellyfin`
  /// mapping — it drives a Jellyfin resource through the host resolver, which now routes on
  /// `mediaServer` — but no test drives an AudiobookShelf resource through one. So
  /// `case .audiobookshelf: .jellyfin` compiles, leaves `mediaServerRawValues` untouched
  /// (it filters on nil-ness, not identity, so the SQL predicate still fetches the rows) and
  /// passes the whole suite, while every AudiobookShelf item resolves against the Jellyfin
  /// connection: nothing to stream, its progress pushes misrouted into the Jellyfin path and
  /// silently dropped by that path's own host guard, and its row wearing the wrong glyph.
  func testProviderNameMapsOntoItsOwnMediaServer() {
    XCTAssertEqual(ExternalResource.ProviderName.jellyfin.mediaServer, .jellyfin)
    XCTAssertEqual(ExternalResource.ProviderName.audiobookshelf.mediaServer, .audiobookshelf)
    XCTAssertNil(ExternalResource.ProviderName.hardcover.mediaServer)
    XCTAssertEqual(
      Set(ExternalResource.ProviderName.mediaServerRawValues),
      ["jellyfin", "audiobookshelf"],
      "the SQL IN predicate reads these strings — they are the stored providerName values"
    )
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
      unresolvedHost: hasUnresolvedExternalHost ? .init(provider: .jellyfin, address: nil) : nil
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
      unresolvedHost: .init(provider: .jellyfin, address: nil)
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

// MARK: - Media-server chapter refresh

/// Fills in the chapters of streamed books that arrived through BookPlayer's own sync with
/// none: nothing ever opens their file, so their server is the only source.
@MainActor
final class MediaServerChapterRefreshServiceTests: XCTestCase {
  /// Records what it was asked and answers every resource with the same chapters, so a test
  /// can assert the fan-out without a server, a keychain or a network.
  private final class ProviderStub: MediaServerChapterProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var _requested: [[String]] = []
    private let chapters: [ChapterMetadata]
    private let fails: Bool

    /// The id sets asked for, one entry per call
    var requested: [[String]] {
      lock.lock()
      defer { lock.unlock() }
      return _requested
    }

    init(chapters: [ChapterMetadata] = [], fails: Bool = false) {
      self.chapters = chapters
      self.fails = fails
    }

    func chapters(for resources: [SimpleExternalResource]) async throws -> [String: [ChapterMetadata]] {
      lock.lock()
      _requested.append(resources.map(\.providerId))
      lock.unlock()
      if fails { throw URLError(.cannotConnectToHost) }
      return Dictionary(uniqueKeysWithValues: resources.map { ($0.providerId, chapters) })
    }
  }

  private let chapters = [
    ChapterMetadata(title: "One", start: 0, duration: 600, index: 1),
    ChapterMetadata(title: "Two", start: 600, duration: 900, index: 2),
  ]

  private func makeResource(provider: String, id: String, hostId: String = "guid-host") -> SimpleExternalResource {
    SimpleExternalResource(
      providerName: provider,
      providerId: id,
      syncStatus: ExternalResource.SyncStatus.stream.rawValue,
      lastSyncedAt: nil,
      hostId: hostId,
      libraryItem: nil
    )
  }

  /// Entitled (lite/pro) unless a test says otherwise: only a synced library brings such rows.
  private func makeSUT(
    chapterless: [SimpleExternalResource],
    providers: [ExternalResource.ProviderName: MediaServerChapterProviding],
    syncEnabled: Bool = true
  ) -> (MediaServerChapterRefreshService, LibraryServiceProtocolMock) {
    let libraryService = LibraryServiceProtocolMock()
    libraryService.findChapterlessMediaServerResourcesAtReturnValue = chapterless
    let accountService = AccountServiceMock(account: nil)
    accountService.hasSyncEnabledValue = syncEnabled

    let sut = MediaServerChapterRefreshService()
    sut.setup(libraryService: libraryService, accountService: accountService, providers: providers)
    return (sut, libraryService)
  }

  /// The level's links come from ONE library query, asked for exactly the path the list is
  /// syncing, and each provider folds its own answers in under its own name.
  func testRefreshAsksBothProvidersForTheLevelsChapterlessBooks() async {
    let jellyfin = ProviderStub(chapters: chapters)
    let abs = ProviderStub(chapters: chapters)
    let (sut, libraryService) = makeSUT(
      chapterless: [makeResource(provider: "jellyfin", id: "jf-1"), makeResource(provider: "audiobookshelf", id: "abs-1")],
      providers: [.jellyfin: jellyfin, .audiobookshelf: abs]
    )

    await sut.refreshChapters(at: "Author/Series")

    XCTAssertEqual(libraryService.findChapterlessMediaServerResourcesAtReceivedInvocations, ["Author/Series"])
    XCTAssertEqual(jellyfin.requested, [["jf-1"]])
    XCTAssertEqual(abs.requested, [["abs-1"]])
    XCTAssertEqual(
      Set(libraryService.storeMediaServerChaptersProviderNameChaptersByProviderIdReceivedInvocations.map(\.providerName)),
      ["jellyfin", "audiobookshelf"]
    )
  }

  func testRefreshForwardsTheServersChaptersUnchanged() async {
    let (sut, libraryService) = makeSUT(
      chapterless: [makeResource(provider: "jellyfin", id: "jf-1")],
      providers: [.jellyfin: ProviderStub(chapters: chapters)]
    )

    await sut.refreshChapters(at: nil)

    let ingested = libraryService.storeMediaServerChaptersProviderNameChaptersByProviderIdReceivedInvocations
    XCTAssertEqual(ingested.first?.chaptersByProviderId["jf-1"], chapters)
  }

  /// The steady state: every book has its chapters, so no server is asked
  func testRefreshAsksNothingWhenEveryBookHasChapters() async {
    let jellyfin = ProviderStub(chapters: chapters)
    let (sut, libraryService) = makeSUT(chapterless: [], providers: [.jellyfin: jellyfin])

    await sut.refreshChapters(at: nil)

    XCTAssertEqual(libraryService.findChapterlessMediaServerResourcesAtReceivedInvocations, [nil], "root is asked as nil")
    XCTAssertTrue(jellyfin.requested.isEmpty)
    XCTAssertEqual(libraryService.storeMediaServerChaptersProviderNameChaptersByProviderIdCallsCount, 0)
  }

  /// One unreachable provider can't keep the other's chapters out
  func testAFailingProviderDoesNotStopTheOther() async {
    let (sut, libraryService) = makeSUT(
      chapterless: [makeResource(provider: "jellyfin", id: "jf-1"), makeResource(provider: "audiobookshelf", id: "abs-1")],
      providers: [.jellyfin: ProviderStub(fails: true), .audiobookshelf: ProviderStub(chapters: chapters)]
    )

    await sut.refreshChapters(at: nil)

    XCTAssertEqual(
      libraryService.storeMediaServerChaptersProviderNameChaptersByProviderIdReceivedInvocations.map(\.providerName),
      ["audiobookshelf"]
    )
  }

  /// Nor one server of a provider another's: an offline server or an expired session leaves out
  /// only its own books
  func testAFailingServerDoesNotStopTheOthers() async {
    let reachable = makeConnection("https://abs.example.com")
    let offline = makeConnection("https://offline.example.com")
    let chapters = chapters

    let chaptersByProviderId = await AudiobookShelfChapterProvider().chaptersByServer(
      [
        makeResource(provider: "audiobookshelf", id: "abs-1", hostId: reachable.stableHostId),
        makeResource(provider: "audiobookshelf", id: "abs-2", hostId: offline.stableHostId),
      ],
      connections: [offline, reachable]
    ) { connection, ids in
      if connection.url == offline.url { throw URLError(.cannotConnectToHost) }
      return Dictionary(uniqueKeysWithValues: ids.map { ($0, chapters) })
    }

    XCTAssertEqual(chaptersByProviderId, ["abs-1": chapters])
  }

  private func makeConnection(_ url: String) -> AudiobookShelfConnectionData {
    AudiobookShelfConnectionData(
      url: URL(string: url)!,
      serverName: "ABS",
      userID: "u1",
      userName: "reader",
      apiToken: "t"
    )
  }

  /// Gated before the library is even queried: a free account costs no fetch at all.
  func testRefreshIsGatedToSyncTiers() async {
    let jellyfin = ProviderStub(chapters: chapters)
    let (sut, libraryService) = makeSUT(
      chapterless: [makeResource(provider: "jellyfin", id: "jf-1")],
      providers: [.jellyfin: jellyfin],
      syncEnabled: false
    )

    await sut.refreshChapters(at: "Folder")

    XCTAssertEqual(libraryService.findChapterlessMediaServerResourcesAtCallsCount, 0)
    XCTAssertTrue(jellyfin.requested.isEmpty)
    XCTAssertEqual(libraryService.storeMediaServerChaptersProviderNameChaptersByProviderIdCallsCount, 0)
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

    XCTAssertEqual(source?.url?.host, "jelly.example.com")
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

  private func mediaServerResource(
    providerName: String = "jellyfin",
    hostId: String = "guid-jelly"
  ) -> SimpleExternalResource {
    SimpleExternalResource(
      providerName: providerName,
      providerId: "item-1",
      syncStatus: ExternalResource.SyncStatus.stream.rawValue,
      lastSyncedAt: nil,
      hostId: hostId,
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

  /// The missing-server alert names the server when the item says where it is: an ABS hostId
  /// is always its address, a Jellyfin one only when the server never reported an id.
  func testAnAddressHostIdIsCarriedForTheAlert() throws {
    let abs = try makeSUT(resolved: false).getPlayableChapters(
      book: makeItem(resources: [
        mediaServerResource(providerName: "audiobookshelf", hostId: "https://abs.example.com/sub")
      ])
    )
    XCTAssertEqual(
      abs.first?.unresolvedHost,
      .init(provider: .audiobookshelf, address: "https://abs.example.com/sub")
    )

    let jellyfinByAddress = try makeSUT(resolved: false).getPlayableChapters(
      book: makeItem(resources: [mediaServerResource(hostId: "HTTP://192.168.1.10:8096")])
    )
    XCTAssertEqual(jellyfinByAddress.first?.unresolvedHost?.address, "HTTP://192.168.1.10:8096")
  }

  /// An id says nothing the user could act on: a Jellyfin GUID, the constant older Android
  /// builds stored for every ABS server, or a legacy numeric id.
  func testAnIdShapedHostIdCarriesNoAddress() throws {
    for (provider, hostId) in [
      ("jellyfin", "guid-jelly"),
      ("audiobookshelf", "server-settings"),
      ("jellyfin", "1"),
    ] {
      let chapters = try makeSUT(resolved: false).getPlayableChapters(
        book: makeItem(resources: [mediaServerResource(providerName: provider, hostId: hostId)])
      )
      XCTAssertTrue(chapters.first?.hasUnresolvedExternalHost ?? false, hostId)
      XCTAssertNil(chapters.first?.unresolvedHost?.address, hostId)
    }
  }

  /// A plain local book has no media server, so a missing file is not a server problem.
  func testItemWithoutResourcesNeverSetsTheFlag() throws {
    let chapters = try makeSUT(resolved: false).getPlayableChapters(book: makeItem(resources: nil))

    XCTAssertNil(chapters.first?.externalUrl)
    XCTAssertFalse(chapters.first?.hasUnresolvedExternalHost ?? true)
  }
}

// MARK: - Provider runtime mapping

/// The runtime is the sole source of an external row's `duration` — nothing opens the file —
/// so where the mapper reads it from decides whether an item is importable at all.
final class JellyfinRuntimeMappingTests: XCTestCase {
  private let twentyMinutesInTicks = 12_000_000_000

  func testItemLevelRuntimeWins() {
    XCTAssertEqual(
      JellyfinLibraryItem.resolveRuntimeSeconds(itemTicks: twentyMinutesInTicks, mediaSourceTicks: 1),
      1200
    )
  }

  func testMediaSourceRuntimeCoversAnItemReportedWithoutOne() {
    XCTAssertEqual(
      JellyfinLibraryItem.resolveRuntimeSeconds(itemTicks: nil, mediaSourceTicks: twentyMinutesInTicks),
      1200,
      "an item Jellyfin hasn't probed still has a runtime on its media source"
    )
  }

  func testNoRuntimeAnywhereStaysUnmeasured() {
    XCTAssertNil(
      JellyfinLibraryItem.resolveRuntimeSeconds(itemTicks: nil, mediaSourceTicks: nil),
      "nil, not 0 — the mapper collapses it to 0 for `durationSeconds`, which the import gate rejects"
    )
  }
}

// MARK: - Virtual import payload

/// The chain this phase exists to protect: the hydrated duration has to survive all the way
/// onto the import payload, because `createExternalBook` copies it straight into
/// `book.duration` and nothing ever measures the file afterwards.
@MainActor
final class VirtualImportPayloadTests: XCTestCase {
  func testAudiobookShelfPayloadCarriesTheHydratedDuration() {
    let item = AudiobookShelfLibraryItem(
      id: "abs-1",
      title: "Dune",
      kind: .audiobook,
      libraryId: "lib",
      duration: 60
    )

    let resource = item.asVirtualImportResource(
      fileExtension: "m4b",
      duration: 4800,
      connectionService: AudiobookShelfConnectionService(),
      artworkSize: CGSize(width: 300, height: 300)
    )

    XCTAssertEqual(
      resource.libraryItem?.duration,
      4800,
      "the HYDRATED length wins over the minified list item's own value"
    )
    XCTAssertEqual(resource.libraryItem?.currentTime, 0, "a streamed book starts at the beginning, as on Android")
    XCTAssertEqual(resource.libraryItem?.percentCompleted, 0)
  }

  func testJellyfinPayloadCarriesTheHydratedDuration() {
    let item = JellyfinLibraryItem(
      id: "jf-1",
      name: "Dune",
      kind: .audiobook,
      durationSeconds: 60,
      blurHash: nil,
      imageAspectRatio: nil,
      details: nil,
      chapters: []
    )

    let resource = item.asVirtualImportResource(
      fileExtension: "m4b",
      duration: 4800,
      detailsOverride: nil,
      connectionService: JellyfinConnectionService(),
      artworkSize: CGSize(width: 200, height: 200)
    )

    XCTAssertEqual(resource.libraryItem?.duration, 4800)
    XCTAssertEqual(resource.libraryItem?.currentTime, 0, "a streamed book starts at the beginning, as on Android")
    XCTAssertEqual(resource.libraryItem?.percentCompleted, 0)
  }
}

/// The file extension decides importability alongside the runtime, and it has the same
/// two-producer hazard: the list mapper and `fetchItemDetails` must agree.
final class JellyfinFileExtensionMappingTests: XCTestCase {
  func testFirstContainerCandidateWins() {
    XCTAssertEqual(
      JellyfinLibraryItem.resolveFileExtension(container: "m4b,mp4,mov", filePath: "/books/Dune.aax"),
      "m4b",
      "Jellyfin reports the container as a candidate list; the first is the real one"
    )
  }

  func testPathExtensionCoversAMissingContainer() {
    XCTAssertEqual(
      JellyfinLibraryItem.resolveFileExtension(container: nil, filePath: "/books/Dune.m4b"),
      "m4b"
    )
  }

  func testNothingToDeriveFromStaysNil() {
    XCTAssertNil(JellyfinLibraryItem.resolveFileExtension(container: nil, filePath: nil))
    XCTAssertEqual(
      JellyfinLibraryItem.resolveFileExtension(container: nil, filePath: "/books/Dune"),
      "",
      "an extensionless path yields an empty string, which the import gate rejects"
    )
  }
}

// MARK: - Media-server chapter mapping

/// A streamed item's chapters can only come from its server: nothing opens the file, and on
/// AudiobookShelf the list may be a server-side edit that isn't in the file at all.
final class MediaServerChapterMappingTests: XCTestCase {
  // MARK: AudiobookShelf — start AND end, so durations are direct

  func testAudiobookShelfChaptersMapWithDirectDurations() {
    let chapters = AudiobookShelfLibraryItem.chapterMetadata(
      from: [
        .init(start: 0, end: 600, title: "One"),
        .init(start: 600, end: 1500, title: "Two"),
      ],
      duration: 1500
    )

    XCTAssertEqual(chapters.map(\.title), ["One", "Two"])
    XCTAssertEqual(chapters.map(\.start), [0, 600])
    XCTAssertEqual(chapters.map(\.duration), [600, 900])
    XCTAssertEqual(chapters.map(\.index), [1, 2], "index is 1-based, matching the playable list")
  }

  func testAudiobookShelfOutOfOrderChaptersAreSortedAndZeroLengthOnesDropped() {
    let chapters = AudiobookShelfLibraryItem.chapterMetadata(
      from: [
        .init(start: 600, end: 1500, title: "Two"),
        .init(start: 700, end: 700, title: "Empty"),
        .init(start: 0, end: 600, title: "One"),
      ],
      duration: 1500
    )

    XCTAssertEqual(
      chapters.map(\.title),
      ["One", "Two"],
      "a zero-length entry would be filtered by getPlayableChapters anyway — don't store it"
    )
  }

  func testAudiobookShelfNoChaptersIsEmptyNotASynthesizedOne() {
    XCTAssertTrue(AudiobookShelfLibraryItem.chapterMetadata(from: nil, duration: 1500).isEmpty)
    XCTAssertTrue(AudiobookShelfLibraryItem.chapterMetadata(from: [], duration: 1500).isEmpty)
  }

  /// The bug this exists for: an uncovered tail resolves to NO chapter, so `PlayableItem.init`
  /// falls back to `chapters[0]` and the session is pinned to chapter 1 — it never advances
  /// (the tick only reassigns when `getChapter` finds one) and never reaches `chapters.last`,
  /// so the book never completes.
  func testAudiobookShelfLastChapterStretchesToTheItemDuration() {
    let chapters = AudiobookShelfLibraryItem.chapterMetadata(
      from: [
        .init(start: 0, end: 600, title: "One"),
        .init(start: 600, end: 1400, title: "Two"),
      ],
      duration: 1500
    )

    XCTAssertEqual(
      chapters.last?.start.advanced(by: chapters.last?.duration ?? 0),
      1500,
      "the chapter track stopping before the trailing silence must not leave a hole"
    )
  }

  func testAudiobookShelfChapterEndBeyondTheDurationIsClamped() {
    let chapters = AudiobookShelfLibraryItem.chapterMetadata(
      from: [.init(start: 0, end: 9999, title: "Overlong")],
      duration: 1500
    )

    XCTAssertEqual(chapters.map(\.duration), [1500])
  }

  func testAudiobookShelfChaptersStartingPastTheDurationAreDropped() {
    let chapters = AudiobookShelfLibraryItem.chapterMetadata(
      from: [
        .init(start: 0, end: 600, title: "One"),
        .init(start: 1600, end: 1700, title: "Bogus"),
      ],
      duration: 1500
    )

    XCTAssertEqual(chapters.map(\.title), ["One"])
    XCTAssertEqual(chapters.map(\.duration), [1500], "the survivor still covers the item")
  }

  func testAudiobookShelfWithoutADurationKeepsTheServersEnds() {
    let chapters = AudiobookShelfLibraryItem.chapterMetadata(
      from: [.init(start: 0, end: 600, title: "One")],
      duration: nil
    )

    XCTAssertEqual(chapters.map(\.duration), [600])
  }

  // MARK: Jellyfin — starts only, so each duration is the gap to the next

  func testJellyfinChapterDurationsDeriveFromTheNextStart() {
    let chapters = JellyfinLibraryItem.chapterMetadata(
      from: [(name: "One", startTicks: 0), (name: "Two", startTicks: 6_000_000_000)],
      runtimeSeconds: 1500
    )

    XCTAssertEqual(chapters.map(\.title), ["One", "Two"])
    XCTAssertEqual(chapters.map(\.start), [0, 600])
    XCTAssertEqual(
      chapters.map(\.duration),
      [600, 900],
      "the last chapter runs to the item runtime, which is the only thing that bounds it"
    )
  }

  func testJellyfinChaptersNeedARuntimeToBeBounded() {
    XCTAssertTrue(
      JellyfinLibraryItem.chapterMetadata(
        from: [(name: "One", startTicks: 0)],
        runtimeSeconds: nil
      ).isEmpty,
      "without a runtime the final chapter has no end; storing a guess is worse than none"
    )
  }

  func testJellyfinChaptersStartingPastTheRuntimeAreDropped() {
    let chapters = JellyfinLibraryItem.chapterMetadata(
      from: [(name: "One", startTicks: 0), (name: "Bogus", startTicks: 99_000_000_000)],
      runtimeSeconds: 1500
    )

    XCTAssertEqual(chapters.map(\.title), ["One"])
    XCTAssertEqual(chapters.map(\.duration), [1500])
  }

  func testJellyfinChaptersWithoutAStartAreSkipped() {
    let chapters = JellyfinLibraryItem.chapterMetadata(
      from: [(name: "Unanchored", startTicks: nil), (name: "One", startTicks: 0)],
      runtimeSeconds: 600
    )

    XCTAssertEqual(chapters.map(\.title), ["One"])
  }
}
