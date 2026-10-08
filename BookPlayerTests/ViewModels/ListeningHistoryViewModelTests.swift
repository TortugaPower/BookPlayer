//
//  ListeningHistoryViewModelTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

@testable import BookPlayer
@testable import BookPlayerKit
import XCTest

@MainActor
final class ListeningHistoryViewModelTests: XCTestCase {
  private var libraryServiceMock: LibraryServiceProtocolMock!
  private var calendar: Calendar!
  private var defaults: UserDefaults!

  override func setUp() {
    super.setUp()
    libraryServiceMock = LibraryServiceProtocolMock()
    calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    defaults = UserDefaults(suiteName: "ListeningHistoryViewModelTests.\(UUID().uuidString)")!
  }

  override func tearDown() {
    defaults.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
    defaults = nil
    super.tearDown()
  }

  private func makeSession(
    id: String = UUID().uuidString,
    relativePath: String = "book.m4b",
    title: String = "Book",
    subtitle: String? = nil,
    artworkRelativePath: String? = nil,
    startedAt: Date,
    duration: Double = 120
  ) -> SimpleListeningSession {
    SimpleListeningSession(
      id: id,
      relativePath: relativePath,
      itemTitle: title,
      subtitle: subtitle,
      artworkRelativePath: artworkRelativePath,
      startedAt: startedAt,
      endedAt: startedAt.addingTimeInterval(duration),
      duration: duration
    )
  }

  private func makeSUT() -> ListeningHistoryViewModel {
    ListeningHistoryViewModel(
      libraryService: libraryServiceMock,
      calendar: calendar,
      defaults: defaults
    )
  }

  func testReload_groupsSessionsByDay() {
    let today = calendar.startOfDay(for: Date())
    let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
    libraryServiceMock.getListeningSessionsFromToRelativePathLimitOffsetReturnValue = [
      makeSession(id: "1", title: "Today Book", startedAt: today.addingTimeInterval(3600)),
      makeSession(id: "2", title: "Yesterday Book", startedAt: yesterday.addingTimeInterval(3600)),
    ]

    let sut = makeSUT()
    sut.reload()

    XCTAssertEqual(sut.sections.count, 2)
    XCTAssertEqual(sut.sections[0].sessions.map(\.id), ["1"])
    XCTAssertEqual(sut.sections[1].sessions.map(\.id), ["2"])
    XCTAssertFalse(sut.isEmpty)
  }

  func testReload_filtersByTitleAndSubtitle() {
    let today = calendar.startOfDay(for: Date())
    libraryServiceMock.getListeningSessionsFromToRelativePathLimitOffsetReturnValue = [
      makeSession(
        id: "1",
        relativePath: "a/file.mp3",
        title: "Dune",
        subtitle: "Part 1",
        startedAt: today.addingTimeInterval(100)
      ),
      makeSession(
        id: "2",
        relativePath: "b/file.mp3",
        title: "Foundation",
        startedAt: today.addingTimeInterval(200)
      ),
    ]

    let sut = makeSUT()
    sut.searchText = "dun"
    sut.reload()

    XCTAssertEqual(sut.sections.count, 1)
    XCTAssertEqual(sut.sections[0].sessions.map(\.id), ["1"])
  }

  func testDateScope_passesRangeToService() {
    libraryServiceMock.getListeningSessionsFromToRelativePathLimitOffsetReturnValue = []
    let sut = makeSUT()
    sut.dateScope = .today
    sut.reload()

    XCTAssertEqual(libraryServiceMock.getListeningSessionsFromToRelativePathLimitOffsetCallsCount, 1)
    let args = libraryServiceMock.getListeningSessionsFromToRelativePathLimitOffsetReceivedArguments
    XCTAssertNotNil(args?.startDate)
    XCTAssertNotNil(args?.endDate)
  }

  func testDeleteSelected_callsServiceAndClearsSelection() {
    let today = calendar.startOfDay(for: Date())
    let session = makeSession(id: "keep-me", startedAt: today)
    libraryServiceMock.getListeningSessionsFromToRelativePathLimitOffsetReturnValue = [session]

    let sut = makeSUT()
    sut.reload()
    sut.selectedIds = ["keep-me", "gone"]
    libraryServiceMock.getListeningSessionsFromToRelativePathLimitOffsetReturnValue = []
    sut.deleteSelected()

    XCTAssertTrue(libraryServiceMock.deleteListeningSessionsIdsCalled)
    XCTAssertEqual(
      libraryServiceMock.deleteListeningSessionsIdsReceivedIds?.sorted(),
      ["gone", "keep-me"]
    )
    XCTAssertTrue(sut.selectedIds.isEmpty)
    XCTAssertTrue(sut.isEmpty)
  }

  func testClearAll_callsServiceAndReloads() {
    libraryServiceMock.getListeningSessionsFromToRelativePathLimitOffsetReturnValue = [
      makeSession(startedAt: Date())
    ]
    let sut = makeSUT()
    sut.reload()
    libraryServiceMock.getListeningSessionsFromToRelativePathLimitOffsetReturnValue = []
    sut.clearAll()

    XCTAssertTrue(libraryServiceMock.deleteAllListeningSessionsCalled)
    XCTAssertTrue(sut.isEmpty)
  }

  func testGroupSessionsByDay_ordersNewestFirst() {
    let today = calendar.startOfDay(for: Date())
    let older = makeSession(id: "older", startedAt: today.addingTimeInterval(100))
    let newer = makeSession(id: "newer", startedAt: today.addingTimeInterval(500))

    let sections = ListeningHistoryViewModel.groupSessionsByDay(
      [older, newer],
      calendar: calendar,
      now: today.addingTimeInterval(1000)
    )

    XCTAssertEqual(sections.count, 1)
    XCTAssertEqual(sections[0].sessions.map(\.id), ["newer", "older"])
  }

  func testPresentation_usesDenormalizedSessionFields() {
    let today = calendar.startOfDay(for: Date())
    let session = makeSession(
      id: "1",
      relativePath: "folder/file.mp3",
      title: "My Folder",
      subtitle: "Nice Book",
      artworkRelativePath: "folder",
      startedAt: today
    )

    let sut = makeSUT()
    let presentation = sut.presentation(for: session)

    XCTAssertEqual(presentation.title, "My Folder")
    XCTAssertEqual(presentation.subtitle, "Nice Book")
    XCTAssertEqual(presentation.artworkRelativePath, "folder")
    XCTAssertEqual(presentation.loadRelativePath, "folder/file.mp3")
  }

  func testReload_readsHistoryDisabledFlag() {
    defaults.set(true, forKey: Constants.UserDefaults.listeningHistoryDisabled)
    libraryServiceMock.getListeningSessionsFromToRelativePathLimitOffsetReturnValue = []

    let sut = makeSUT()
    sut.reload()

    XCTAssertTrue(sut.isHistoryDisabled)
  }
}
