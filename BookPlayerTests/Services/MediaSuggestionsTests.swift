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
  private var controller: MediaSuggestionsController!

  override func setUp() {
    recorder = Recorder()
    bookPlayed = PassthroughSubject()
    metadataUpdates = PassthroughSubject()
  }

  private func makeController() {
    let recorder = recorder!
    controller = MediaSuggestionsController()
    controller.setup(dependencies: .init(
      recentItems: { Array(recorder.recentItems.prefix($0)) },
      bookCount: { 42 },
      boundBookAuthor: { recorder.boundBookAuthors[$0] },
      hasSyncEnabled: { recorder.hasSyncEnabled },
      artworkData: { _ in nil },
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
      metadataUpdates: metadataUpdates.eraseToAnyPublisher()
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

  private func playableItem(_ name: String, uuid: String? = nil) -> PlayableItem {
    let relativePath = "Folder/\(name).m4b"
    let chapter = PlayableChapter(
      title: name,
      author: "Author \(name)",
      start: 0,
      duration: 100,
      relativePath: relativePath,
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
    /// The sink hops to the main queue: let it run
    let drained = expectation(description: "main queue drained")
    DispatchQueue.main.async { drained.fulfill() }
    await fulfillment(of: [drained], timeout: 1)

    XCTAssertTrue(recorder.deletedGroups.isEmpty)
    XCTAssertEqual(recorder.suggestions.count, refreshes)
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
