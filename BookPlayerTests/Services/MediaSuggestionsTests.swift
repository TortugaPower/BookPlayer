//
//  MediaSuggestionsTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Combine
import Foundation
import Intents
import XCTest

@testable import BookPlayer
@testable import BookPlayerKit

/// What the controller hands the system
private final class Recorder {
  var recentItems = [SimpleLibraryItem]()
  var boundBookAuthors = [String: String]()
  var hasSyncEnabled = false
  /// The cover every book has (only the books at `artworkPaths`, when set), the paths each cover was
  /// asked for, and a wait before each answer
  var artwork: Data?
  var artworkPaths: Set<String>?
  var artworkRequests = [[String]]()
  var artworkGate: (() async -> Void)?
  var donations = [INInteraction]()
  var deletedGroups = [String]()
  var suggestions = [[INPlayMediaIntent]]()
  var contexts = [INMediaUserContext]()
  var onDelete: (() -> Void)?
  var onSuggest: (() -> Void)?
}

@MainActor
final class MediaSuggestionsTests: XCTestCase {
  private var recorder: Recorder!
  private var bookPlayed: PassthroughSubject<PlayableItem, Never>!
  private var metadataUpdates: PassthroughSubject<[String: Any], Never>!
  private var artworkUpdates: PassthroughSubject<String, Never>!
  private var controller: MediaSuggestionsController!

  override func setUp() {
    recorder = Recorder()
    bookPlayed = PassthroughSubject()
    metadataUpdates = PassthroughSubject()
    artworkUpdates = PassthroughSubject()
  }

  private func makeController() {
    let recorder = recorder!
    controller = MediaSuggestionsController()
    controller.setup(dependencies: .init(
      recentItems: { Array(recorder.recentItems.prefix($0)) },
      bookCount: { 42 },
      boundBookAuthor: { recorder.boundBookAuthors[$0] },
      hasSyncEnabled: { recorder.hasSyncEnabled },
      artworkData: { paths in
        recorder.artworkRequests.append(paths)
        await recorder.artworkGate?()
        guard paths.contains(where: { recorder.artworkPaths?.contains($0) ?? true }) else { return nil }
        return recorder.artwork
      },
      donate: { recorder.donations.append($0) },
      deleteDonations: {
        recorder.deletedGroups.append($0)
        recorder.onDelete?()
      },
      setSuggestedIntents: {
        recorder.suggestions.append($0)
        recorder.onSuggest?()
      },
      setUserContext: { recorder.contexts.append($0) },
      bookPlayed: bookPlayed.eraseToAnyPublisher(),
      metadataUpdates: metadataUpdates.eraseToAnyPublisher(),
      artworkUpdates: artworkUpdates.eraseToAnyPublisher()
    ))
  }

  private func libraryItem(
    _ name: String,
    isFinished: Bool = false,
    type: SimpleItemType = .book,
    parentFolder: String = "Folder",
    lastPlayDate: Date? = Date()
  ) -> SimpleLibraryItem {
    SimpleLibraryItem(
      title: name,
      details: type == .bound ? "12 files" : "Author \(name)",
      speed: 1,
      currentTime: 0,
      duration: 100,
      percentCompleted: 0,
      isFinished: isFinished,
      relativePath: "\(parentFolder)/\(name).m4b",
      remoteURL: nil,
      artworkURL: nil,
      orderRank: 0,
      parentFolder: parentFolder,
      originalFileName: "\(name).m4b",
      lastPlayDate: lastPlayDate,
      type: type,
      uuid: "uuid-\(name)"
    )
  }

  /// A bound book's chapters are its parts, at their own paths
  private func playableItem(_ name: String, uuid: String? = nil, partPath: String? = nil) -> PlayableItem {
    let relativePath = "Folder/\(name).m4b"
    let chapter = PlayableChapter(
      title: name,
      author: "Author \(name)",
      start: 0,
      duration: 100,
      relativePath: partPath ?? relativePath,
      remoteURL: nil,
      externalURL: nil,
      index: 0
    )
    return PlayableItem(
      title: name,
      author: "Author \(name)",
      chapters: [chapter],
      currentTime: 0,
      duration: 100,
      relativePath: relativePath,
      uuid: uuid ?? "uuid-\(name)",
      parentFolder: "Folder",
      percentCompleted: 0,
      lastPlayDate: nil,
      isFinished: false,
      isBoundBook: false
    )
  }

  private func play(_ item: PlayableItem) async {
    bookPlayed.send(item)
    await controller.pendingDonation?.value
    await controller.pendingRefresh?.value
  }

  /// The sinks hop to the main queue: let them run
  private func drainMainQueue() async {
    let drained = expectation(description: "main queue drained")
    DispatchQueue.main.async { drained.fulfill() }
    await fulfillment(of: [drained], timeout: 1)
  }

  // MARK: - User context

  func testUserContext_marksASyncTierAsSubscribed() {
    recorder.hasSyncEnabled = true
    makeController()

    XCTAssertEqual(recorder.contexts.count, 1, "once, at launch")
    XCTAssertEqual(recorder.contexts.first?.subscriptionStatus, .subscribed)
    XCTAssertEqual(recorder.contexts.first?.numberOfLibraryItems, 42)
  }

  func testUserContext_leavesTheStatusUnknownWithoutASyncTier() {
    makeController()

    XCTAssertEqual(recorder.contexts.first?.subscriptionStatus, .unknown, "never notSubscribed: free users play everything")
    XCTAssertEqual(recorder.contexts.first?.numberOfLibraryItems, 42)
  }

  // MARK: - Upcoming media

  func testUpcoming_offersTheMostRecentUnfinishedBooks() async {
    recorder.recentItems = ["a", "b", "c", "d", "e", "f", "g"].map {
      libraryItem($0, isFinished: $0 == "b")
    }
    makeController()
    await controller.pendingRefresh?.value

    let intents = recorder.suggestions.last ?? []
    XCTAssertEqual(
      intents.map { $0.mediaContainer?.identifier },
      ["uuid-a", "uuid-c", "uuid-d", "uuid-e", "uuid-f"],
      "the finished one is skipped and the list stops at five"
    )
    XCTAssertEqual(intents.first?.mediaContainer?.title, "a")
    XCTAssertEqual(intents.first?.mediaContainer?.artist, "Author a")
    XCTAssertEqual(intents.first?.mediaContainer?.type, .audioBook)
    XCTAssertTrue(intents.allSatisfy { $0.mediaItems == nil }, "the book is the container and nothing else is set")
  }

  func testUpcoming_namesABoundBooksAuthorByItsFirstPart() async {
    recorder.recentItems = [libraryItem("bound", type: .bound), libraryItem("empty", type: .bound)]
    recorder.boundBookAuthors = ["Folder/bound.m4b": "Part Author"]
    makeController()
    await controller.pendingRefresh?.value

    let containers = (recorder.suggestions.last ?? []).map { $0.mediaContainer }
    XCTAssertEqual(containers.first??.artist, "Part Author", "not the bound book's file count")
    XCTAssertNil(containers.last??.artist, "a bound book with no parts has no author to show")
  }

  // MARK: - Donations

  func testBookPlayed_donatesEachBookOnce() async {
    makeController()

    await play(playableItem("a"))
    await play(playableItem("a"))
    await play(playableItem("b"))

    XCTAssertEqual(recorder.donations.map(\.groupIdentifier), ["uuid-a", "uuid-b"], "a resume isn't a new start")

    let donation = recorder.donations.first
    let intent = donation?.intent as? INPlayMediaIntent
    XCTAssertEqual(intent?.mediaContainer?.identifier, "uuid-a")
    XCTAssertEqual(intent?.mediaContainer?.title, "a")
    XCTAssertNil(intent?.mediaItems)
    XCTAssertEqual((donation?.intentResponse as? INPlayMediaIntentResponse)?.code, .success)
  }

  func testBookPlayed_namesABookWithoutAUuidByItsPath() async {
    makeController()

    await play(playableItem("a", uuid: ""))

    XCTAssertEqual(recorder.donations.first?.groupIdentifier, "Folder/a.m4b")
  }

  func testBookPlayed_skipsABookLeftWhileItsCoverWasRead() async {
    makeController()
    await controller.pendingRefresh?.value

    var release: CheckedContinuation<Void, Never>?
    let reading = expectation(description: "cover being read")
    recorder.artworkGate = {
      await withCheckedContinuation { continuation in
        release = continuation
        reading.fulfill()
      }
    }
    bookPlayed.send(playableItem("a"))
    let first = controller.pendingDonation
    await fulfillment(of: [reading], timeout: 1)

    recorder.artworkGate = nil
    await play(playableItem("b"))
    release?.resume()
    await first?.value

    XCTAssertEqual(recorder.donations.map(\.groupIdentifier), ["uuid-b"], "a donated after b would look more recent")
  }

  func testBookPlayed_refreshesTheUpcomingBooks() async {
    makeController()
    await controller.pendingRefresh?.value
    let refreshes = recorder.suggestions.count

    await play(playableItem("a"))

    XCTAssertEqual(recorder.suggestions.count, refreshes + 1)
  }

  // MARK: - Finished books

  func testFinishingABook_deletesItsDonationsAndRefreshes() async {
    makeController()
    await play(playableItem("a"))
    let refreshes = recorder.suggestions.count

    let deleted = expectation(description: "donations deleted")
    recorder.onDelete = { deleted.fulfill() }
    metadataUpdates.send(["relativePath": "Folder/a.m4b", "uuid": "uuid-a", "isFinished": true])
    await fulfillment(of: [deleted], timeout: 1)
    await controller.pendingRefresh?.value

    XCTAssertEqual(recorder.deletedGroups, ["uuid-a"])
    XCTAssertEqual(recorder.suggestions.count, refreshes + 1)

    await play(playableItem("a"))
    XCTAssertEqual(recorder.donations.count, 2, "listening to it again is a new start")
  }

  func testMarkingABookUnfinished_refreshesWithoutDeleting() async {
    makeController()
    await controller.pendingRefresh?.value

    let suggested = expectation(description: "upcoming books refreshed")
    recorder.onSuggest = { suggested.fulfill() }
    metadataUpdates.send(["relativePath": "Folder/a.m4b", "uuid": "uuid-a", "isFinished": false])
    await fulfillment(of: [suggested], timeout: 1)

    XCTAssertTrue(recorder.deletedGroups.isEmpty)
  }

  func testOtherMetadataUpdates_changeNothing() async {
    makeController()
    await controller.pendingRefresh?.value
    let refreshes = recorder.suggestions.count

    metadataUpdates.send(["relativePath": "Folder/a.m4b", "uuid": "uuid-a", "title": "Renamed"])
    await drainMainQueue()

    XCTAssertTrue(recorder.deletedGroups.isEmpty)
    XCTAssertEqual(recorder.suggestions.count, refreshes)
  }

  // MARK: - Artwork

  func testArtwork_shrinksEachBooksCoverOncePerLaunch() async {
    recorder.recentItems = [libraryItem("a"), libraryItem("b")]
    recorder.artwork = Data("cover".utf8)
    makeController()
    await controller.pendingRefresh?.value

    await play(playableItem("a"))
    await play(playableItem("b"))

    XCTAssertEqual(
      recorder.artworkRequests,
      [["Folder/a.m4b"], ["Folder/b.m4b"]],
      "the donations and the later refreshes reuse them"
    )
    XCTAssertNotNil((recorder.donations.last?.intent as? INPlayMediaIntent)?.mediaContainer?.artwork)
    XCTAssertTrue((recorder.suggestions.last ?? []).allSatisfy { $0.mediaContainer?.artwork != nil })
  }

  func testArtwork_isShrunkAgainOnceACoverChanges() async {
    recorder.recentItems = [libraryItem("a")]
    recorder.artwork = Data("cover".utf8)
    makeController()
    await controller.pendingRefresh?.value

    artworkUpdates.send("Folder/a.m4b")
    await drainMainQueue()
    await play(playableItem("a"))

    XCTAssertEqual(recorder.artworkRequests.count, 2, "asked again for the donation, then reused by the refresh")
  }

  func testArtwork_dropsACoverReadBeforeItChanged() async {
    recorder.recentItems = [libraryItem("a")]
    recorder.artwork = Data("old".utf8)
    var release: CheckedContinuation<Void, Never>?
    let reading = expectation(description: "cover being read")
    recorder.artworkGate = {
      await withCheckedContinuation { continuation in
        release = continuation
        reading.fulfill()
      }
    }
    makeController()
    await fulfillment(of: [reading], timeout: 1)

    recorder.artworkGate = nil
    artworkUpdates.send("Folder/a.m4b")
    await drainMainQueue()
    release?.resume()
    await controller.pendingRefresh?.value
    await play(playableItem("a"))

    XCTAssertEqual(recorder.artworkRequests.count, 2, "the old cover wasn't kept for the launch")
  }

  func testArtwork_keepsOnlyTheListedBooksCovers() async {
    recorder.artwork = Data("cover".utf8)
    makeController()
    await controller.pendingRefresh?.value

    /// Not listed: its cover goes when the refresh after its donation ends
    await play(playableItem("a"))
    recorder.recentItems = [libraryItem("a")]
    await play(playableItem("b"))

    XCTAssertEqual(recorder.artworkRequests.filter { $0 == ["Folder/a.m4b"] }.count, 2)
  }

  func testArtwork_keepsABoundBookOnItsFolderCoverOnly() async {
    recorder.recentItems = [libraryItem("a")]
    recorder.artwork = Data("cover".utf8)
    recorder.artworkPaths = ["Folder/a/1.mp3"]
    makeController()
    await controller.pendingRefresh?.value

    await play(playableItem("a", partPath: "Folder/a/1.mp3"))

    let donation = recorder.donations.last?.intent as? INPlayMediaIntent
    XCTAssertNotNil(donation?.mediaContainer?.artwork, "the playing part's cover stands in")
    XCTAssertNil(recorder.suggestions.last?.first?.mediaContainer?.artwork, "and isn't kept for the folder")

    /// The library caches the folder's own cover when it shows it
    recorder.artworkPaths = nil
    let suggested = expectation(description: "upcoming books refreshed")
    recorder.onSuggest = { suggested.fulfill() }
    metadataUpdates.send(["relativePath": "Folder/a.m4b", "uuid": "uuid-a", "isFinished": false])
    await fulfillment(of: [suggested], timeout: 1)

    XCTAssertNotNil(recorder.suggestions.last?.first?.mediaContainer?.artwork)
  }

  func testArtwork_isAskedForAgainWhileABookHasNone() async {
    recorder.recentItems = [libraryItem("a")]
    makeController()
    await controller.pendingRefresh?.value

    /// The library caches it when it shows the book, without an artwork update
    recorder.artwork = Data("cover".utf8)
    await play(playableItem("b"))

    XCTAssertEqual(recorder.artworkRequests.filter { $0 == ["Folder/a.m4b"] }.count, 2)
    XCTAssertNotNil(recorder.suggestions.last?.first?.mediaContainer?.artwork)
  }

  func testThumbnail_shrinksACoverToTheSuggestionSizeOnly() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    func cover(width: Int, height: Int) throws -> URL {
      let format = UIGraphicsImageRendererFormat()
      format.scale = 1
      let size = CGSize(width: width, height: height)
      let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
        UIColor.red.setFill()
        context.fill(CGRect(origin: .zero, size: size))
      }
      let url = directory.appendingPathComponent("\(width)x\(height).png")
      try XCTUnwrap(image.pngData()).write(to: url)
      return url
    }

    let large = try XCTUnwrap(
      MediaSuggestionsController.thumbnailData(at: cover(width: 1200, height: 600)).flatMap(UIImage.init(data:))
    )
    XCTAssertEqual(large.size, CGSize(width: 256, height: 128))

    let small = try XCTUnwrap(
      MediaSuggestionsController.thumbnailData(at: cover(width: 100, height: 50)).flatMap(UIImage.init(data:))
    )
    XCTAssertEqual(small.size, CGSize(width: 100, height: 50), "never enlarged")

    XCTAssertNil(MediaSuggestionsController.thumbnailData(at: directory.appendingPathComponent("missing.png")))
  }

  // MARK: - Playing what an intent names

  func testBook_findsWhatWasSaidOrTheLastPlayed() {
    let found = libraryItem("found")
    let last = libraryItem("last")
    func book(matching query: String?) -> SimpleLibraryItem? {
      PlayMediaIntentHandler.book(
        matching: query,
        search: { $0 == "found" ? [found] : [] },
        lastPlayed: { last },
        boundBook: { _ in nil }
      )
    }

    XCTAssertEqual(book(matching: "found")?.relativePath, found.relativePath)
    XCTAssertNil(book(matching: "missing"), "nothing matches: not the last played book instead")
    XCTAssertEqual(book(matching: nil)?.relativePath, last.relativePath, "\"Play BookPlayer\" says no book")
    XCTAssertEqual(book(matching: "")?.relativePath, last.relativePath)
  }

  func testBook_playsABoundBookForOneOfItsParts() {
    let part = libraryItem("part-2", parentFolder: "Bound", lastPlayDate: nil)
    let bound = libraryItem("Bound", type: .bound)

    let book = PlayMediaIntentHandler.book(
      matching: "part",
      search: { _ in [part] },
      lastPlayed: { nil },
      boundBook: { $0.parentFolder == "Bound" ? bound : nil }
    )

    XCTAssertEqual(book?.relativePath, bound.relativePath, "as the Search tab shows it")
  }

  func testBook_ranksABoundBookByItsOwnPlayDate() {
    let now = Date()
    let olderBook = libraryItem("older", lastPlayDate: now.addingTimeInterval(-3600))
    /// The author is only on the parts, and binding cleared their play dates
    let part = libraryItem("part-1", parentFolder: "Bound", lastPlayDate: nil)
    let bound = libraryItem("Bound", type: .bound, lastPlayDate: now)

    let book = PlayMediaIntentHandler.book(
      matching: "Author",
      search: { _ in [olderBook, part] },
      lastPlayed: { nil },
      boundBook: { $0.parentFolder == "Bound" ? bound : nil }
    )

    XCTAssertEqual(book?.relativePath, bound.relativePath, "played after the other match")
  }

  func testBoundBookPath_mapsAPartToItsBoundBookOnly() throws {
    DataTestUtils.clearFolderContents(url: DataManager.getProcessedFolderURL())
    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))
    let libraryService = LibraryService()
    libraryService.setup(dataManager: dataManager, audioMetadataService: AudioMetadataService())
    let library = libraryService.getLibrary()

    let rootBook = StubFactory.book(dataManager: dataManager, title: "root", duration: 100)
    library.addToItems(rootBook)
    let folder = try StubFactory.folder(dataManager: dataManager, title: "folder")
    library.addToItems(folder)
    let folderBook = StubFactory.book(dataManager: dataManager, title: "folder-book", duration: 100)
    folder.addToItems(folderBook)
    let bound = try StubFactory.folder(dataManager: dataManager, title: "bound")
    bound.type = .bound
    library.addToItems(bound)
    let part = StubFactory.book(dataManager: dataManager, title: "part", duration: 100)
    bound.addToItems(part)
    dataManager.saveContext()

    func boundBookPath(_ item: BookPlayerKit.LibraryItem) -> String? {
      PlayMediaIntentHandler.boundBookPath(of: item.relativePath ?? "", in: libraryService)
    }

    XCTAssertEqual(boundBookPath(part), bound.relativePath)
    XCTAssertNil(boundBookPath(bound), "a bound book plays itself")
    XCTAssertNil(boundBookPath(folderBook), "a plain folder's books play on their own")
    XCTAssertNil(boundBookPath(rootBook))
  }

  func testRelativePath_findsTheBookByUuidThenByPath() {
    let pathsByUuid = ["uuid-a": "Moved/a.m4b", "uuid-unbound": "Unbound", "uuid-part": "Bound/part-1.m4b"]
    let books: Set<String> = ["Moved/a.m4b", "Folder/b.m4b", "Bound/part-1.m4b"]
    func resolve(_ identifier: String) -> String? {
      PlayMediaIntentHandler.relativePath(
        for: identifier,
        uuidLookup: { pathsByUuid[$0] },
        isBook: { books.contains($0) },
        boundBookPath: { $0.hasPrefix("Bound/") ? "Bound" : nil }
      )
    }

    XCTAssertEqual(resolve("uuid-a"), "Moved/a.m4b", "a uuid finds the book wherever it is now")
    XCTAssertEqual(resolve("Folder/b.m4b"), "Folder/b.m4b", "a book without a uuid was named by its path")
    XCTAssertNil(resolve("uuid-gone"), "a deleted book")
    XCTAssertNil(resolve("uuid-unbound"), "a bound book made a plain folder isn't a book anymore")
    XCTAssertEqual(resolve("uuid-part"), "Bound", "a book donated before its folder was bound plays the bound book")
  }
}
