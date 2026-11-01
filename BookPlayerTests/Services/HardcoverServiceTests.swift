//
//  HardcoverServiceTests.swift
//  BookPlayerTests
//
//  Created by gianni.carlo on 18/10/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

@testable import BookPlayer
@testable import BookPlayerKit
import Combine
import XCTest

/// Hardcover's API keys (`hc_pat_…`) come without the `Bearer` scheme its older tokens were copied with
class HardcoverServiceTests: XCTestCase {
  var sut: HardcoverService!
  var mockKeychain: KeychainServiceMock!

  override func setUp() {
    mockKeychain = KeychainServiceMock()
    sut = HardcoverService()
    sut.setup(
      libraryService: LibraryServiceProtocolMock(),
      syncService: SyncServiceProtocolMock(),
      keychain: mockKeychain
    )
  }

  func testApiKeyKeepsABareKey() {
    XCTAssertEqual(HardcoverService.apiKey(from: "hc_pat_abc123"), "hc_pat_abc123")
  }

  func testApiKeyDropsTheBearerScheme() {
    XCTAssertEqual(HardcoverService.apiKey(from: "Bearer hc_pat_abc123"), "hc_pat_abc123")
    XCTAssertEqual(HardcoverService.apiKey(from: "bearer   eyJhbGciOiJSUzI1NiJ9"), "eyJhbGciOiJSUzI1NiJ9")
    XCTAssertEqual(HardcoverService.apiKey(from: "BEARER\thc_pat_abc123"), "hc_pat_abc123")
  }

  func testApiKeyTrimsWhitespaceAndNewlines() {
    XCTAssertEqual(HardcoverService.apiKey(from: "  Bearer hc_pat_abc123 \n"), "hc_pat_abc123")
  }

  func testApiKeyOfTheSchemeAloneIsEmpty() {
    XCTAssertEqual(HardcoverService.apiKey(from: "Bearer"), "")
    XCTAssertEqual(HardcoverService.apiKey(from: "Bearer "), "")
    XCTAssertEqual(HardcoverService.apiKey(from: "   "), "")
  }

  func testApiKeyKeepsAKeyThatOnlyStartsWithBearer() {
    XCTAssertEqual(HardcoverService.apiKey(from: "bearerish_key"), "bearerish_key")
  }

  func testSavingAPastedBearerTokenStoresTheBareKey() throws {
    sut.authorization = "Bearer hc_pat_abc123"

    XCTAssertEqual(try mockKeychain.get(.hardcoverToken), "hc_pat_abc123")
    XCTAssertEqual(sut.authorization, "hc_pat_abc123")
  }

  func testATokenSavedWithItsBearerSchemeReadsBare() throws {
    try mockKeychain.set("Bearer eyJhbGciOiJSUzI1NiJ9", key: .hardcoverToken)

    XCTAssertEqual(sut.authorization, "eyJhbGciOiJSUzI1NiJ9")
  }

  func testSavingTheSchemeAloneRemovesTheToken() throws {
    sut.authorization = "hc_pat_abc123"
    sut.authorization = "Bearer "

    XCTAssertNil(try mockKeychain.get(.hardcoverToken))
    XCTAssertNil(sut.authorization)
  }
}

/// Connecting with an API key or by signing in, and the account written on the links it makes
class HardcoverConnectionTests: XCTestCase {
  var sut: HardcoverService!
  var mockKeychain: KeychainServiceMock!
  var libraryService: LibraryServiceProtocolMock!

  private let defaults = UserDefaults.sharedDefaults
  private var savedDefaults: [String: Any?] = [:]
  private let defaultsKeys = [
    Constants.UserDefaults.hardcoverUserId,
    Constants.UserDefaults.hardcoverUsername,
    Constants.UserDefaults.hardcoverAutoAddWantToRead,
  ]

  override func setUp() {
    for key in defaultsKeys {
      savedDefaults[key] = defaults.object(forKey: key)
      defaults.removeObject(forKey: key)
    }

    mockKeychain = KeychainServiceMock()
    libraryService = LibraryServiceProtocolMock()
    sut = HardcoverService()
    sut.setup(
      libraryService: libraryService,
      syncService: SyncServiceProtocolMock(),
      keychain: mockKeychain
    )
  }

  override func tearDown() {
    for key in defaultsKeys {
      if let value = savedDefaults[key] ?? nil {
        defaults.set(value, forKey: key)
      } else {
        defaults.removeObject(forKey: key)
      }
    }
  }

  func testNotConnectedWithoutAKeyOrASignIn() {
    XCTAssertFalse(sut.isConnected)
    XCTAssertFalse(sut.isSignedInWithOAuth)
  }

  func testAnAPIKeyConnects() {
    sut.authorization = "hc_pat_abc123"

    XCTAssertTrue(sut.isConnected)
    XCTAssertFalse(sut.isSignedInWithOAuth)
  }

  func testASignInConnects() throws {
    try mockKeychain.set(
      HardcoverTokenSet(accessToken: "hc_at_a", refreshToken: "hc_rt_a", scope: "", expiresAt: nil),
      key: .hardcoverSession
    )

    XCTAssertTrue(sut.isConnected)
    XCTAssertTrue(sut.isSignedInWithOAuth)
  }

  func testSavingTheSameKeyKeepsTheAccount() {
    sut.authorization = "hc_pat_abc123"
    defaults.set("42", forKey: Constants.UserDefaults.hardcoverUserId)
    defaults.set("reader", forKey: Constants.UserDefaults.hardcoverUsername)

    sut.authorization = "Bearer hc_pat_abc123"

    XCTAssertEqual(defaults.string(forKey: Constants.UserDefaults.hardcoverUserId), "42")
    XCTAssertEqual(sut.connectedUsername, "reader")
  }

  func testAnotherKeyForgetsTheAccount() {
    sut.authorization = "hc_pat_abc123"
    defaults.set("42", forKey: Constants.UserDefaults.hardcoverUserId)
    defaults.set("reader", forKey: Constants.UserDefaults.hardcoverUsername)

    sut.authorization = "hc_pat_other"

    XCTAssertNil(defaults.string(forKey: Constants.UserDefaults.hardcoverUserId))
    XCTAssertNil(sut.connectedUsername)
  }

  func testALinkRecordsTheConnectedAccountAsItsHost() async {
    sut.authorization = "hc_pat_abc123"
    defaults.set("42", forKey: Constants.UserDefaults.hardcoverUserId)
    defaults.set(false, forKey: Constants.UserDefaults.hardcoverAutoAddWantToRead)

    await sut.assignItem(makeBook(), to: makeItem())

    let arguments = libraryService.setExternalResourceProviderNameProviderIdHostIdForReceivedArguments
    XCTAssertEqual(arguments?.providerName, ExternalResource.ProviderName.hardcover.rawValue)
    XCTAssertEqual(arguments?.providerId, "12345")
    XCTAssertEqual(arguments?.hostId, "42")
  }

  func testDisconnectingForgetsTheKeyAndTheAccount() async {
    sut.authorization = "hc_pat_abc123"
    defaults.set("42", forKey: Constants.UserDefaults.hardcoverUserId)

    await sut.disconnect()

    XCTAssertFalse(sut.isConnected)
    XCTAssertNil(defaults.string(forKey: Constants.UserDefaults.hardcoverUserId))
  }

  private func makeBook() -> SimpleHardcoverBook {
    SimpleHardcoverBook(id: 12345, artworkURL: nil, title: "Book", author: "Author", status: .local)
  }

  private func makeItem() -> SimpleLibraryItem {
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
      uuid: "UUID"
    )
  }
}

/// A book's percentage carried onto Hardcover's read: kept ahead of what's there and short of the end
class HardcoverReadProgressTests: XCTestCase {
  typealias Edition = ReadInProgressData.Edition

  let audiobook = Edition(id: 10, pages: nil, audioSeconds: 36_000, readingFormatId: 2)
  let paperback = Edition(id: 20, pages: 300, audioSeconds: nil, readingFormatId: 1)

  private func read(seconds: Int? = nil, pages: Int? = nil, edition: Edition? = nil) -> ReadInProgressData.Read {
    ReadInProgressData.Read(id: 1, progressPages: pages, progressSeconds: seconds, edition: edition)
  }

  func testAudiobookEditionGetsSeconds() {
    let progress = HardcoverReadProgress.update(percent: 25, read: read(edition: audiobook))
    XCTAssertEqual(progress, HardcoverReadProgress(unit: .seconds, value: 9_000, editionId: nil))
    XCTAssertEqual(progress?.object, ["progress_seconds": 9_000])
  }

  func testPrintEditionGetsPages() {
    XCTAssertEqual(
      HardcoverReadProgress.update(percent: 50, read: read(edition: paperback)),
      HardcoverReadProgress(unit: .pages, value: 150, editionId: nil)
    )
  }

  /// The format decides, as in Hardcover's SDK: a print edition's recording length isn't used
  func testFormatDecidesTheUnit() {
    let print = Edition(id: 30, pages: 200, audioSeconds: 1_000, readingFormatId: 1)
    XCTAssertEqual(HardcoverReadProgress.update(percent: 50, read: read(edition: print))?.unit, .pages)
  }

  /// A read started by a status change has no edition: it takes the book's default audiobook
  /// one, written with the progress
  func testReadWithoutEditionTakesTheDefaultAudiobookOne() {
    let progress = HardcoverReadProgress.update(percent: 50, read: read(), fallbacks: [audiobook])
    XCTAssertEqual(progress, HardcoverReadProgress(unit: .seconds, value: 18_000, editionId: 10))
    XCTAssertEqual(progress?.object, ["progress_seconds": 18_000, "edition_id": 10])
  }

  func testLibraryEntryEditionComesBeforeTheDefault() {
    XCTAssertEqual(
      HardcoverReadProgress.update(percent: 50, read: read(), fallbacks: [paperback, audiobook]),
      HardcoverReadProgress(unit: .pages, value: 150, editionId: 20)
    )
  }

  func testEditionWithoutLengthIsPassedOver() {
    let unknown = Edition(id: 40, pages: nil, audioSeconds: nil, readingFormatId: 2)
    XCTAssertEqual(
      HardcoverReadProgress.update(percent: 50, read: read(), fallbacks: [unknown, audiobook])?
        .editionId,
      10
    )
  }

  /// A read's own edition with a length is kept, even with others available
  func testReadsOwnEditionWithALengthIsKept() {
    XCTAssertEqual(
      HardcoverReadProgress.update(percent: 50, read: read(edition: paperback), fallbacks: [audiobook]),
      HardcoverReadProgress(unit: .pages, value: 150, editionId: nil)
    )
  }

  /// Hardcover gives a read the default print edition, which can have no page count: another
  /// edition with a length replaces it, and progress recorded against the old one doesn't count
  func testReadsOwnEditionWithoutALengthIsReplaced() {
    let noPages = Edition(id: 40, pages: nil, audioSeconds: nil, readingFormatId: 1)
    XCTAssertEqual(
      HardcoverReadProgress.update(percent: 50, read: read(pages: 999, edition: noPages), fallbacks: [audiobook]),
      HardcoverReadProgress(unit: .seconds, value: 18_000, editionId: 10)
    )
  }

  /// No audiobook edition (common for translations): the default print edition, in pages
  func testBookWithoutAudiobookEditionFallsBackToPrint() {
    let progress = HardcoverReadProgress.update(percent: 50, read: read(), fallbacks: [nil, nil, nil, paperback])
    XCTAssertEqual(progress, HardcoverReadProgress(unit: .pages, value: 150, editionId: 20))
  }

  func testSkipsSayWhy() {
    XCTAssertEqual(
      HardcoverReadProgress.evaluate(percent: 50, read: read(), fallbacks: [nil]),
      .failure(.noLength)
    )
    XCTAssertEqual(
      HardcoverReadProgress.evaluate(percent: 10, read: read(seconds: 9_000, edition: audiobook)),
      .failure(.notAhead(current: 9_000, value: 3_600))
    )
  }

  /// Defaults without a length (this book's only one was print with no page count): the most
  /// read edition with a length
  func testDefaultsWithoutALengthFallBackToTheMostReadEditions() throws {
    let json = """
      {"default_audio_edition": null, "default_ebook_edition": null,
       "default_physical_edition": {"id": 40, "pages": null, "audio_seconds": null, "reading_format_id": 1},
       "audio_editions": [{"id": 10, "pages": null, "audio_seconds": 36000, "reading_format_id": 2}],
       "paged_editions": []}
      """
    let book = try JSONDecoder().decode(ReadInProgressData.Book.self, from: Data(json.utf8))
    let noPages = Edition(id: 40, pages: nil, audioSeconds: nil, readingFormatId: 1)

    XCTAssertEqual(
      HardcoverReadProgress.update(percent: 50, read: read(edition: noPages), fallbacks: [noPages] + book.defaultEditions),
      HardcoverReadProgress(unit: .seconds, value: 18_000, editionId: 10)
    )
  }

  func testNoEditionSendsNothing() {
    XCTAssertNil(HardcoverReadProgress.update(percent: 50, read: read()))
  }

  func testNotAheadOfHardcoverSendsNothing() {
    XCTAssertNil(HardcoverReadProgress.update(percent: 25, read: read(seconds: 9_000, edition: audiobook)))
    XCTAssertNil(HardcoverReadProgress.update(percent: 10, read: read(seconds: 9_000, edition: audiobook)))
    XCTAssertNil(HardcoverReadProgress.update(percent: 40, read: read(pages: 150, edition: paperback)))
  }

  /// Reaching the end would finish the read; that's the Read status's job
  func testStaysShortOfTheEnd() {
    let short = Edition(id: 50, pages: nil, audioSeconds: 1_000, readingFormatId: 2)
    XCTAssertEqual(HardcoverReadProgress.update(percent: 99.99, read: read(edition: short))?.value, 999)
    XCTAssertNil(HardcoverReadProgress.update(percent: 100, read: read(edition: short)))
    XCTAssertNil(HardcoverReadProgress.update(percent: 0, read: read(edition: short)))
  }
}

class HardcoverProgressScheduleTests: XCTestCase {
  let start = Date(timeIntervalSince1970: 1_000)

  func testFirstUpdateGoesRightAway() {
    var schedule = HardcoverProgressSchedule(interval: 120)
    XCTAssertEqual(schedule.record(10, for: "a", at: start), 10)
  }

  func testUpdatesWithinTheIntervalAreHeldThenSent() {
    var schedule = HardcoverProgressSchedule(interval: 120)
    _ = schedule.record(10, for: "a", at: start)

    XCTAssertNil(schedule.record(11, for: "a", at: start.addingTimeInterval(30)))
    XCTAssertNil(schedule.record(12, for: "a", at: start.addingTimeInterval(60)))
    XCTAssertEqual(schedule.record(13, for: "a", at: start.addingTimeInterval(120)), 13)
    XCTAssertTrue(schedule.flush(at: start.addingTimeInterval(121)).isEmpty)
  }

  func testBooksAreScheduledApart() {
    var schedule = HardcoverProgressSchedule(interval: 120)
    _ = schedule.record(10, for: "a", at: start)
    XCTAssertEqual(schedule.record(50, for: "b", at: start.addingTimeInterval(1)), 50)
  }

  func testFlushSendsTheLatestHeldAndRestartsTheInterval() {
    var schedule = HardcoverProgressSchedule(interval: 120)
    _ = schedule.record(10, for: "a", at: start)
    _ = schedule.record(11, for: "a", at: start.addingTimeInterval(10))
    _ = schedule.record(12, for: "a", at: start.addingTimeInterval(20))

    let held = schedule.flush(at: start.addingTimeInterval(30))
    XCTAssertEqual(held.map(\.relativePath), ["a"])
    XCTAssertEqual(held.map(\.percent), [12])
    XCTAssertTrue(schedule.flush(at: start.addingTimeInterval(31)).isEmpty)
    XCTAssertNil(schedule.record(13, for: "a", at: start.addingTimeInterval(60)))
  }
}

/// A `me` lookup still in flight when the credentials change belongs to the previous account
class HardcoverAccountLookupTests: XCTestCase {
  var sut: HardcoverService!
  var mockKeychain: KeychainServiceMock!

  private let defaults = UserDefaults.sharedDefaults
  private var savedDefaults: [String: Any?] = [:]
  private let defaultsKeys = [
    Constants.UserDefaults.hardcoverUserId,
    Constants.UserDefaults.hardcoverUsername,
  ]

  override func setUp() {
    for key in defaultsKeys {
      savedDefaults[key] = defaults.object(forKey: key)
      defaults.removeObject(forKey: key)
    }
    GatedMeStub.reset()
  }

  override func tearDown() {
    GatedMeStub.open()
    for key in defaultsKeys {
      if let value = savedDefaults[key] ?? nil {
        defaults.set(value, forKey: key)
      } else {
        defaults.removeObject(forKey: key)
      }
    }
  }

  func testALookupForReplacedCredentialsIsNotCached() async throws {
    let sentWithOldKey = expectation(description: "both lookups for the old key are in flight")
    /// The one `setup` starts, and the one below
    sentWithOldKey.expectedFulfillmentCount = 2
    GatedMeStub.onOldKeyRequest = { sentWithOldKey.fulfill() }

    mockKeychain = KeychainServiceMock()
    try mockKeychain.set(GatedMeStub.oldKey, key: .hardcoverToken)
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [GatedMeStub.self]
    /// Connected from the start, so `setup` starts tracking the library
    let libraryService = LibraryServiceProtocolMock()
    libraryService.metadataUpdatePublisher = Empty().eraseToAnyPublisher()
    libraryService.progressUpdatePublisher = Empty().eraseToAnyPublisher()
    sut = HardcoverService()
    sut.setup(
      libraryService: libraryService,
      syncService: SyncServiceProtocolMock(),
      keychain: mockKeychain,
      graphQLSession: URLSession(configuration: configuration)
    )

    let lookup = Task { [sut] in await sut!.fetchConnectedUserId() }
    await fulfillment(of: [sentWithOldKey], timeout: 5)

    sut.authorization = "hc_pat_new"
    GatedMeStub.open()

    let staleUserId = await lookup.value
    XCTAssertNil(staleUserId)
    XCTAssertNotEqual(defaults.string(forKey: Constants.UserDefaults.hardcoverUserId), GatedMeStub.oldUserId)

    let userId = await sut.fetchConnectedUserId()
    XCTAssertEqual(userId, GatedMeStub.newUserId)
    XCTAssertEqual(sut.connectedUsername, "new_reader")
  }
}

/// Answers `me` by the key sent: user 42 for the old key, 7 for any other. Holds every answer
/// until `open()`, so a test can change the credentials while a lookup is in flight
private final class GatedMeStub: URLProtocol {
  static let oldKey = "hc_pat_old"
  static let oldUserId = "42"
  static let newUserId = "7"

  private static let lock = NSLock()
  private static var isOpen = false
  private static var waiting = [GatedMeStub]()
  static var onOldKeyRequest: (() -> Void)?

  static func reset() {
    lock.withLock {
      isOpen = false
      waiting = []
      onOldKeyRequest = nil
    }
  }

  static func open() {
    let held = lock.withLock {
      isOpen = true
      defer { waiting = [] }
      return waiting
    }
    held.forEach { $0.respond() }
  }

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    let (isOpen, onOldKeyRequest) = Self.lock.withLock {
      if !Self.isOpen { Self.waiting.append(self) }
      return (Self.isOpen, Self.onOldKeyRequest)
    }

    if isOldKey { onOldKeyRequest?() }
    if isOpen { respond() }
  }

  override func stopLoading() {}

  private var isOldKey: Bool {
    request.value(forHTTPHeaderField: "Authorization") == "Bearer \(Self.oldKey)"
  }

  private func respond() {
    let (id, username) = isOldKey ? (Self.oldUserId, "old_reader") : (Self.newUserId, "new_reader")
    let body = #"{"data":{"me":[{"id":\#(id),"username":"\#(username)"}]}}"#
    let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Data(body.utf8))
    client?.urlProtocolDidFinishLoading(self)
  }
}
