//
//  LibraryServiceListeningSessionTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

@testable import BookPlayer
@testable import BookPlayerKit
import XCTest

final class LibraryServiceListeningSessionTests: XCTestCase {
  var sut: LibraryService!

  override func setUp() {
    DataTestUtils.clearFolderContents(url: DataManager.getProcessedFolderURL())
    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))
    let audioMetadataService = AudioMetadataService()
    sut = LibraryService()
    sut.setup(dataManager: dataManager, audioMetadataService: audioMetadataService)
    _ = sut.getLibrary()
  }

  func testStartTickEnd_persistsCompletedSession() {
    _ = sut.startListeningSession(relativePath: "book.m4b", title: "Book", subtitle: nil, artworkRelativePath: nil)
    for _ in 0..<15 {
      sut.recordListeningSessionTick()
    }
    sut.endListeningSession()

    let sessions = sut.getListeningSessions(
      from: nil,
      to: nil,
      relativePath: nil,
      limit: nil,
      offset: nil
    )

    XCTAssertEqual(sessions.count, 1)
    XCTAssertEqual(sessions[0].relativePath, "book.m4b")
    XCTAssertEqual(sessions[0].itemTitle, "Book")
    XCTAssertGreaterThanOrEqual(sessions[0].duration, 15)
    XCTAssertNotNil(sessions[0].endedAt)
  }

  func testEnd_discardsSessionUnderMinimumDuration() {
    _ = sut.startListeningSession(relativePath: "book.m4b", title: "Book", subtitle: nil, artworkRelativePath: nil)
    for _ in 0..<5 {
      sut.recordListeningSessionTick()
    }
    sut.endListeningSession()

    let sessions = sut.getListeningSessions(
      from: nil,
      to: nil,
      relativePath: nil,
      limit: nil,
      offset: nil
    )
    XCTAssertTrue(sessions.isEmpty)
  }

  func testStart_appearsInHistoryWhileActive() {
    _ = sut.startListeningSession(relativePath: "book.m4b", title: "Book", subtitle: nil, artworkRelativePath: nil)

    let sessions = sut.getListeningSessions(
      from: nil,
      to: nil,
      relativePath: nil,
      limit: nil,
      offset: nil
    )

    XCTAssertEqual(sessions.count, 1)
    XCTAssertNil(sessions[0].endedAt)
    XCTAssertEqual(sessions[0].relativePath, "book.m4b")
  }

  func testStart_samePath_reusesActiveSession() {
    let first = sut.startListeningSession(relativePath: "book.m4b", title: "Book", subtitle: nil, artworkRelativePath: nil)
    for _ in 0..<10 { sut.recordListeningSessionTick() }
    let second = sut.startListeningSession(relativePath: "book.m4b", title: "Book", subtitle: nil, artworkRelativePath: nil)

    XCTAssertEqual(first.id, second.id)
    XCTAssertEqual(second.duration, 10, accuracy: 0.001)
  }

  func testStart_endsPreviousActiveSession() {
    _ = sut.startListeningSession(relativePath: "first.m4b", title: "First", subtitle: nil, artworkRelativePath: nil)
    for _ in 0..<15 {
      sut.recordListeningSessionTick()
    }

    _ = sut.startListeningSession(relativePath: "second.m4b", title: "Second", subtitle: nil, artworkRelativePath: nil)
    for _ in 0..<15 {
      sut.recordListeningSessionTick()
    }
    sut.endListeningSession()

    let sessions = sut.getListeningSessions(
      from: nil,
      to: nil,
      relativePath: nil,
      limit: nil,
      offset: nil
    )
    XCTAssertEqual(sessions.count, 2)
    XCTAssertEqual(sessions[0].relativePath, "second.m4b")
    XCTAssertEqual(sessions[1].relativePath, "first.m4b")
  }

  func testGetListeningSessions_filtersByRelativePathAndDate() {
    let calendar = Calendar.current
    let todayStart = calendar.startOfDay(for: Date())

    _ = sut.startListeningSession(relativePath: "a.m4b", title: "A", subtitle: nil, artworkRelativePath: nil)
    for _ in 0..<15 { sut.recordListeningSessionTick() }
    sut.endListeningSession()

    _ = sut.startListeningSession(relativePath: "b.m4b", title: "B", subtitle: nil, artworkRelativePath: nil)
    for _ in 0..<15 { sut.recordListeningSessionTick() }
    sut.endListeningSession()

    let forA = sut.getListeningSessions(
      from: nil,
      to: nil,
      relativePath: "a.m4b",
      limit: nil,
      offset: nil
    )
    XCTAssertEqual(forA.count, 1)
    XCTAssertEqual(forA[0].relativePath, "a.m4b")

    let tomorrow = calendar.date(byAdding: .day, value: 1, to: todayStart)!
    let todaySessions = sut.getListeningSessions(
      from: todayStart,
      to: tomorrow,
      relativePath: nil,
      limit: nil,
      offset: nil
    )
    XCTAssertEqual(todaySessions.count, 2)

    let count = sut.getListeningSessionsCount(from: todayStart, to: tomorrow, relativePath: "b.m4b")
    XCTAssertEqual(count, 1)
  }

  func testDeleteListeningSessions_byIds() {
    _ = sut.startListeningSession(relativePath: "a.m4b", title: "A", subtitle: nil, artworkRelativePath: nil)
    for _ in 0..<15 { sut.recordListeningSessionTick() }
    sut.endListeningSession()

    _ = sut.startListeningSession(relativePath: "b.m4b", title: "B", subtitle: nil, artworkRelativePath: nil)
    for _ in 0..<15 { sut.recordListeningSessionTick() }
    sut.endListeningSession()

    let all = sut.getListeningSessions(
      from: nil, to: nil, relativePath: nil, limit: nil, offset: nil
    )
    XCTAssertEqual(all.count, 2)

    sut.deleteListeningSessions(ids: [all[0].id])
    let remaining = sut.getListeningSessions(
      from: nil, to: nil, relativePath: nil, limit: nil, offset: nil
    )
    XCTAssertEqual(remaining.count, 1)
    XCTAssertEqual(remaining[0].id, all[1].id)
  }

  func testDeleteAllListeningSessions() {
    _ = sut.startListeningSession(relativePath: "a.m4b", title: "A", subtitle: nil, artworkRelativePath: nil)
    for _ in 0..<15 { sut.recordListeningSessionTick() }
    sut.endListeningSession()

    sut.deleteAllListeningSessions()
    let remaining = sut.getListeningSessions(
      from: nil, to: nil, relativePath: nil, limit: nil, offset: nil
    )
    XCTAssertTrue(remaining.isEmpty)
  }

  func testEndListeningSession_prunesSessionsOlderThanRetention() {
    let context = sut.dataManager.getContext()
    let oldSession = ListeningSession.create(in: context)
    oldSession.relativePath = "old.m4b"
    oldSession.itemTitle = "Old"
    oldSession.startedAt = Calendar.current.date(byAdding: .day, value: -400, to: Date())!
    oldSession.endedAt = oldSession.startedAt.addingTimeInterval(60)
    oldSession.duration = 60
    sut.dataManager.saveContext()

    _ = sut.startListeningSession(relativePath: "new.m4b", title: "New", subtitle: nil, artworkRelativePath: nil)
    for _ in 0..<15 { sut.recordListeningSessionTick() }
    sut.endListeningSession()

    let sessions = sut.getListeningSessions(
      from: nil, to: nil, relativePath: nil, limit: nil, offset: nil
    )
    XCTAssertEqual(sessions.count, 1)
    XCTAssertEqual(sessions[0].relativePath, "new.m4b")
  }

  func testEnd_closesAllOrphanOpenSessions() {
    let context = sut.dataManager.getContext()
    let first = ListeningSession.create(in: context)
    first.relativePath = "orphan-a.m4b"
    first.itemTitle = "A"
    first.startedAt = Date().addingTimeInterval(-3600)
    first.endedAt = nil
    first.duration = 60

    let second = ListeningSession.create(in: context)
    second.relativePath = "orphan-b.m4b"
    second.itemTitle = "B"
    second.startedAt = Date().addingTimeInterval(-1800)
    second.endedAt = nil
    second.duration = 60
    sut.dataManager.saveContext()

    sut.endListeningSession()

    let sessions = sut.getListeningSessions(
      from: nil, to: nil, relativePath: nil, limit: nil, offset: nil
    )
    XCTAssertEqual(sessions.count, 2)
    XCTAssertTrue(sessions.allSatisfy { $0.endedAt != nil })
  }
}
