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
  typealias Edition = HardcoverReadInProgressData.Edition

  let audiobook = Edition(id: 10, pages: nil, audioSeconds: 36_000, readingFormatId: 2)
  let paperback = Edition(id: 20, pages: 300, audioSeconds: nil, readingFormatId: 1)

  private func read(seconds: Int? = nil, pages: Int? = nil, edition: Edition? = nil) -> HardcoverReadInProgressData.Read {
    HardcoverReadInProgressData.Read(id: 1, progressPages: pages, progressSeconds: seconds, edition: edition)
  }

  func testAudiobookEditionGetsSeconds() {
    let progress = HardcoverReadProgress.update(percent: 25, read: read(edition: audiobook))
    XCTAssertEqual(progress, HardcoverReadProgress(unit: .seconds, value: 9_000))
    XCTAssertEqual(progress?.object, ["progress_seconds": 9_000])
  }

  func testPrintEditionGetsPages() {
    let progress = HardcoverReadProgress.update(percent: 50, read: read(edition: paperback))
    XCTAssertEqual(progress, HardcoverReadProgress(unit: .pages, value: 150))
    XCTAssertEqual(progress?.object, ["progress_pages": 150])
  }

  /// The format decides, as in Hardcover's SDK: a print edition's recording length isn't used
  func testFormatDecidesTheUnit() {
    let print = Edition(id: 30, pages: 200, audioSeconds: 1_000, readingFormatId: 1)
    XCTAssertEqual(HardcoverReadProgress.update(percent: 50, read: read(edition: print))?.unit, .pages)
  }

  /// An edition without a format counts as an audiobook only with a duration: a zero one with
  /// pages is a paged edition
  func testAnEditionWithoutAFormatIsAnAudiobookOnlyWithADuration() {
    let unformatted = Edition(id: 30, pages: 200, audioSeconds: 0, readingFormatId: nil)
    XCTAssertEqual(
      HardcoverReadProgress.update(percent: 50, read: read(edition: unformatted)),
      HardcoverReadProgress(unit: .pages, value: 100)
    )
  }

  /// The read's edition is the user's: one without a length isn't swapped for another, so nothing
  /// is sent (Hardcover's default print edition can have no page count)
  func testAReadsEditionWithoutALengthSendsNothing() {
    let noPages = Edition(id: 40, pages: nil, audioSeconds: nil, readingFormatId: 1)
    XCTAssertEqual(
      HardcoverReadProgress.evaluate(percent: 50, read: read(pages: 10, edition: noPages)),
      .failure(.noLength)
    )
  }

  func testSkipsSayWhy() {
    XCTAssertEqual(
      HardcoverReadProgress.evaluate(percent: 50, read: read()),
      .failure(.noLength)
    )
    XCTAssertEqual(
      HardcoverReadProgress.evaluate(percent: 10, read: read(seconds: 9_000, edition: audiobook)),
      .failure(.notAhead(current: 9_000, value: 3_600))
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

/// A book's progress goes to Hardcover when its percentage changes, not on every progress tick
class HardcoverProgressChangesTests: XCTestCase {
  func testABooksFirstPercentIsSent() {
    var changes = HardcoverProgressChanges()
    XCTAssertTrue(changes.isNew(10, forItem: "a"))
  }

  /// Ticks every 10 s while the whole percent stays the same: one send for all of them
  func testTheSamePercentIsNotSentAgain() {
    var changes = HardcoverProgressChanges()
    _ = changes.isNew(10, forItem: "a")

    XCTAssertFalse(changes.isNew(10, forItem: "a"))
    XCTAssertFalse(changes.isNew(10, forItem: "a"))
    XCTAssertTrue(changes.isNew(11, forItem: "a"))
    XCTAssertFalse(changes.isNew(11, forItem: "a"))
  }

  /// Going back is a change too; Hardcover keeps the higher value (the write is only forward)
  func testAPercentGoingBackIsSent() {
    var changes = HardcoverProgressChanges()
    _ = changes.isNew(40, forItem: "a")

    XCTAssertTrue(changes.isNew(20, forItem: "a"))
  }

  func testBooksAreTrackedApart() {
    var changes = HardcoverProgressChanges()
    _ = changes.isNew(10, forItem: "a")

    XCTAssertTrue(changes.isNew(10, forItem: "b"))
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

/// Drives `HardcoverService` against `HardcoverAPIStub`, signed in with an API key and with the
/// account already known, so no `me` lookup is made
class HardcoverAPITestCase: XCTestCase {
  var sut: HardcoverService!
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
    HardcoverAPIStub.reset()

    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [HardcoverAPIStub.self]
    libraryService = LibraryServiceProtocolMock()
    sut = HardcoverService()
    sut.setup(
      libraryService: libraryService,
      syncService: SyncServiceProtocolMock(),
      keychain: KeychainServiceMock(),
      graphQLSession: URLSession(configuration: configuration)
    )
    sut.authorization = "hc_pat_abc123"
    defaults.set("42", forKey: Constants.UserDefaults.hardcoverUserId)
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

  func makeItem() -> SimpleLibraryItem {
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

/// A book BookPlayer adds to the user's Hardcover library goes in as its audiobook edition, so the
/// read Hardcover starts on it counts listening time; a book they already have keeps its edition
class HardcoverAddToLibraryTests: HardcoverAPITestCase {
  override func setUp() {
    super.setUp()
    UserDefaults.sharedDefaults.set(true, forKey: Constants.UserDefaults.hardcoverAutoAddWantToRead)
    HardcoverAPIStub.answer("InsertUserBook", with: #"{"data":{"insert_user_book":{"id":555}}}"#)
  }

  func testANewBookGoesInAsItsDefaultAudiobookEdition() async throws {
    answerLookup(
      userBooks: "[]",
      defaultAudio: #"{"id":300,"audio_seconds":88764}"#,
      audioEditions: #"[{"id":301,"audio_seconds":88740}]"#
    )

    await sut.assignItem(makeBook(), to: makeItem())

    let object = try XCTUnwrap(insertedObjects.first)
    XCTAssertEqual(object["book_id"] as? Int, 12345)
    XCTAssertEqual(object["status_id"] as? Int, 1)
    XCTAssertEqual(object["edition_id"] as? Int, 300)
    let lookup = try XCTUnwrap(HardcoverAPIStub.variables(of: "LibraryEntry").first)
    XCTAssertEqual(lookup["user_id"] as? Int, 42)
    XCTAssertEqual(lookup["book_id"] as? Int, 12345)
  }

  func testADefaultAudiobookEditionWithoutADurationGivesWayToTheMostReadOne() async throws {
    answerLookup(
      userBooks: "[]",
      defaultAudio: #"{"id":300,"audio_seconds":null}"#,
      audioEditions: #"[{"id":301,"audio_seconds":56880}]"#
    )

    await sut.assignItem(makeBook(), to: makeItem())

    let object = try XCTUnwrap(insertedObjects.first)
    XCTAssertEqual(object["edition_id"] as? Int, 301)
  }

  func testABookAlreadyInTheLibraryKeepsItsEdition() async throws {
    answerLookup(
      userBooks: #"[{"id":9}]"#,
      defaultAudio: #"{"id":300,"audio_seconds":88764}"#,
      audioEditions: "[]"
    )

    await sut.assignItem(makeBook(), to: makeItem())

    let object = try XCTUnwrap(insertedObjects.first)
    XCTAssertEqual(object["book_id"] as? Int, 12345)
    XCTAssertNil(object["edition_id"])
  }

  func testABookWithoutAnAudiobookEditionLeavesTheEditionToHardcover() async throws {
    answerLookup(userBooks: "[]", defaultAudio: "null", audioEditions: "[]")

    await sut.assignItem(makeBook(), to: makeItem())

    let object = try XCTUnwrap(insertedObjects.first)
    XCTAssertNil(object["edition_id"])
  }

  func testAFailedLookupStillAddsTheBook() async throws {
    HardcoverAPIStub.answer("LibraryEntry", with: #"{"errors":[{"message":"down"}]}"#)

    await sut.assignItem(makeBook(), to: makeItem())

    let object = try XCTUnwrap(insertedObjects.first)
    XCTAssertEqual(object["book_id"] as? Int, 12345)
    XCTAssertNil(object["edition_id"])
  }

  private var insertedObjects: [[String: Any]] {
    HardcoverAPIStub.variables(of: "InsertUserBook").compactMap { $0["object"] as? [String: Any] }
  }

  private func answerLookup(userBooks: String, defaultAudio: String, audioEditions: String) {
    HardcoverAPIStub.answer(
      "LibraryEntry",
      with: #"{"data":{"user_books":\#(userBooks),"books_by_pk":{"default_audio_edition":\#(defaultAudio),"audio_editions":\#(audioEditions)}}}"#
    )
  }

  private func makeBook() -> SimpleHardcoverBook {
    SimpleHardcoverBook(id: 12345, artworkURL: nil, title: "Book", author: "Author", status: .local)
  }
}

/// A book's progress goes on its read in progress on Hardcover, measured against the read's own
/// edition, and only while it's Currently Reading there
class HardcoverProgressSyncTests: HardcoverAPITestCase {
  override func setUp() {
    super.setUp()
    libraryService.getHardcoverBookForReturnValue = makeBook(status: .reading)
    HardcoverAPIStub.answer("UpdateProgress", with: #"{"data":{"update_user_book_read":{"error":null}}}"#)
  }

  func testProgressGoesOnTheReadInProgressInItsEditionsUnit() async throws {
    answerReadInProgress(statusId: 2, progressSeconds: 100, edition: Self.audiobook)

    try await sut.updateReadProgress(50, for: "book.m4b")

    let query = try XCTUnwrap(HardcoverAPIStub.variables(of: "ReadInProgress").first)
    XCTAssertEqual(query["user_id"] as? Int, 42)
    XCTAssertEqual(query["book_id"] as? Int, 12345)

    let mutation = try XCTUnwrap(HardcoverAPIStub.variables(of: "UpdateProgress").first)
    XCTAssertEqual(mutation["id"] as? Int, 77)
    let object = try XCTUnwrap(mutation["object"] as? [String: Any])
    XCTAssertEqual(object["progress_seconds"] as? Int, 500)
    XCTAssertEqual(object.count, 1, "Only the progress: the read's edition and dates stay as they are")
  }

  func testAPrintEditionGetsPages() async throws {
    answerReadInProgress(statusId: 2, progressPages: nil, edition: #"{"id":20,"pages":300,"audio_seconds":null,"reading_format_id":1}"#)

    try await sut.updateReadProgress(50, for: "book.m4b")

    let mutation = try XCTUnwrap(HardcoverAPIStub.variables(of: "UpdateProgress").first)
    XCTAssertEqual((mutation["object"] as? [String: Any])?["progress_pages"] as? Int, 150)
  }

  func testNothingIsSentUnlessItsCurrentlyReadingOnHardcover() async throws {
    answerReadInProgress(statusId: 1, progressSeconds: nil, edition: Self.audiobook)

    try await sut.updateReadProgress(50, for: "book.m4b")

    XCTAssertTrue(HardcoverAPIStub.variables(of: "UpdateProgress").isEmpty)
  }

  func testNothingIsAskedBeforeTheBookIsCurrentlyReading() async throws {
    libraryService.getHardcoverBookForReturnValue = makeBook(status: .library)

    try await sut.updateReadProgress(50, for: "book.m4b")

    XCTAssertTrue(HardcoverAPIStub.variables(of: "ReadInProgress").isEmpty)
    XCTAssertTrue(HardcoverAPIStub.variables(of: "UpdateProgress").isEmpty)
  }

  func testAReadsEditionWithoutALengthGetsNothing() async throws {
    answerReadInProgress(statusId: 2, progressPages: nil, edition: #"{"id":40,"pages":null,"audio_seconds":null,"reading_format_id":1}"#)

    try await sut.updateReadProgress(50, for: "book.m4b")

    XCTAssertTrue(HardcoverAPIStub.variables(of: "UpdateProgress").isEmpty)
  }

  func testProgressBehindHardcoversIsNotSent() async throws {
    answerReadInProgress(statusId: 2, progressSeconds: 600, edition: Self.audiobook)

    try await sut.updateReadProgress(50, for: "book.m4b")

    XCTAssertTrue(HardcoverAPIStub.variables(of: "UpdateProgress").isEmpty)
  }

  private static let audiobook = #"{"id":10,"pages":null,"audio_seconds":1000,"reading_format_id":2}"#

  private func answerReadInProgress(
    statusId: Int,
    progressSeconds: Int? = nil,
    progressPages: Int? = nil,
    edition: String
  ) {
    let seconds = progressSeconds.map(String.init) ?? "null"
    let pages = progressPages.map(String.init) ?? "null"
    HardcoverAPIStub.answer(
      "ReadInProgress",
      with: #"{"data":{"user_books":[{"id":9,"status_id":\#(statusId),"user_book_reads":[{"id":77,"progress_seconds":\#(seconds),"progress_pages":\#(pages),"edition":\#(edition)}]}]}}"#
    )
  }

  private func makeBook(status: HardcoverBook.Status) -> SimpleHardcoverBook {
    SimpleHardcoverBook(id: 12345, artworkURL: nil, title: "Book", author: "Author", status: status)
  }
}

/// A queued progress task sends the book's percentage as it is when the task runs, with the
/// Currently Reading status first; it throws only what's worth retrying
class HardcoverQueuedProgressTests: HardcoverAPITestCase {
  override func setUp() {
    super.setUp()
    libraryService.getSimpleItemForReturnValue = makeItem(percent: 60)
    libraryService.getHardcoverBookForReturnValue = makeBook(status: .reading)
    libraryService.getExternalResourcesForReturnValue = [
      SimpleExternalResource(
        providerName: ExternalResource.ProviderName.hardcover.rawValue,
        providerId: "12345",
        syncStatus: "synced",
        lastSyncedAt: nil
      )
    ]
    HardcoverAPIStub.answer(
      "ReadInProgress",
      with: #"{"data":{"user_books":[{"id":9,"status_id":2,"user_book_reads":[{"id":77,"progress_seconds":100,"progress_pages":null,"edition":{"id":10,"pages":null,"audio_seconds":1000,"reading_format_id":2}}]}]}}"#
    )
    HardcoverAPIStub.answer("UpdateProgress", with: #"{"data":{"update_user_book_read":{"error":null}}}"#)
    HardcoverAPIStub.answer("InsertUserBook", with: #"{"data":{"insert_user_book":{"id":555}}}"#)
  }

  func testATaskSendsTheBooksPercentageWhenItRuns() async throws {
    /// Queued at 50%, played on to 60% while it waited
    try await sut.syncProgress(uuid: "UUID", relativePath: "book.m4b", percentCompleted: 50)

    XCTAssertEqual(libraryService.getSimpleItemForReceivedUuid, "UUID")
    let mutation = try XCTUnwrap(HardcoverAPIStub.variables(of: "UpdateProgress").first)
    XCTAssertEqual((mutation["object"] as? [String: Any])?["progress_seconds"] as? Int, 600)
  }

  func testABookBackAtTheStartIsDropped() async throws {
    libraryService.getSimpleItemForReturnValue = makeItem(percent: 0)

    try await sut.syncProgress(uuid: "UUID", relativePath: "book.m4b", percentCompleted: 50)

    XCTAssertTrue(HardcoverAPIStub.variables(of: "ReadInProgress").isEmpty)
  }

  func testAFinishedBookIsDropped() async throws {
    libraryService.getSimpleItemForReturnValue = makeItem(percent: 100, isFinished: true)

    try await sut.syncProgress(uuid: "UUID", relativePath: "book.m4b", percentCompleted: 99)

    XCTAssertTrue(HardcoverAPIStub.variables(of: "ReadInProgress").isEmpty)
  }

  func testAGoneBookIsDropped() async throws {
    libraryService.getSimpleItemForReturnValue = nil

    try await sut.syncProgress(uuid: "UUID", relativePath: "book.m4b", percentCompleted: 50)

    XCTAssertTrue(HardcoverAPIStub.variables(of: "ReadInProgress").isEmpty)
  }

  func testATaskLeftFromAnUnlinkedAccountIsDropped() async throws {
    sut.authorization = nil

    try await sut.syncProgress(uuid: "UUID", relativePath: "book.m4b", percentCompleted: 50)

    XCTAssertTrue(HardcoverAPIStub.variables(of: "ReadInProgress").isEmpty)
  }

  func testCurrentlyReadingGoesBeforeTheProgress() async throws {
    libraryService.getHardcoverBookForReturnValue = makeBook(status: .library)

    try await sut.syncProgress(uuid: "UUID", relativePath: "book.m4b", percentCompleted: 60)

    let insert = try XCTUnwrap(HardcoverAPIStub.variables(of: "InsertUserBook").first)
    XCTAssertEqual((insert["object"] as? [String: Any])?["status_id"] as? Int, 2)
  }

  func testAStatusChangeThatCantGoThroughHoldsTheProgress() async {
    libraryService.getHardcoverBookForReturnValue = makeBook(status: .library)
    HardcoverAPIStub.fail("InsertUserBook", status: 503)

    await assertRetried()
    XCTAssertTrue(HardcoverAPIStub.variables(of: "ReadInProgress").isEmpty)
  }

  func testABusyServerIsRetried() async {
    HardcoverAPIStub.fail("ReadInProgress", status: 503)

    await assertRetried()
  }

  func testARateLimitIsRetried() async {
    HardcoverAPIStub.fail("UpdateProgress", status: 429)

    await assertRetried()
  }

  func testARefusedRequestIsDropped() async throws {
    HardcoverAPIStub.fail("ReadInProgress", status: 400)

    try await sut.syncProgress(uuid: "UUID", relativePath: "book.m4b", percentCompleted: 60)

    XCTAssertTrue(HardcoverAPIStub.variables(of: "UpdateProgress").isEmpty)
  }

  private func assertRetried(file: StaticString = #filePath, line: UInt = #line) async {
    do {
      try await sut.syncProgress(uuid: "UUID", relativePath: "book.m4b", percentCompleted: 60)
      XCTFail("Expected the failure to be thrown for a retry", file: file, line: line)
    } catch {
      XCTAssertTrue(HardcoverService.isTransient(error), "\(error)", file: file, line: line)
    }
  }

  private func makeItem(percent: Double, isFinished: Bool = false) -> SimpleLibraryItem {
    SimpleLibraryItem(
      title: "Book",
      details: "Author",
      speed: 1,
      currentTime: percent * 10,
      duration: 1000,
      percentCompleted: percent,
      isFinished: isFinished,
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

  private func makeBook(status: HardcoverBook.Status) -> SimpleHardcoverBook {
    SimpleHardcoverBook(id: 12345, artworkURL: nil, title: "Book", author: "Author", status: status)
  }
}

/// What the Hardcover lane retries, and how long it waits
class HardcoverRetryTests: XCTestCase {
  func testNoConnectionAndTimeoutsAreRetried() {
    XCTAssertTrue(HardcoverService.isTransient(URLError(.notConnectedToInternet)))
    XCTAssertTrue(HardcoverService.isTransient(URLError(.timedOut)))
    XCTAssertTrue(HardcoverService.isTransient(URLError(.networkConnectionLost)))
    XCTAssertFalse(HardcoverService.isTransient(URLError(.cancelled)))
    XCTAssertFalse(HardcoverService.isTransient(URLError(.badServerResponse)))
  }

  func testABusyOrFailingServerIsRetried() {
    for status in [408, 429, 500, 502, 503, 504] {
      XCTAssertTrue(HardcoverService.isTransient(GraphQLClient.Error.httpError(status)), "\(status)")
    }
    for status in [400, 401, 403, 404, 422] {
      XCTAssertFalse(HardcoverService.isTransient(GraphQLClient.Error.httpError(status)), "\(status)")
    }
  }

  func testATokenRefreshFailingTheSameWayIsRetried() {
    XCTAssertTrue(HardcoverService.isTransient(HardcoverOAuthError.http(503)))
    XCTAssertTrue(HardcoverService.isTransient(HardcoverOAuthError.http(429)))
    XCTAssertFalse(HardcoverService.isTransient(HardcoverOAuthError.http(400)))
    XCTAssertFalse(HardcoverService.isTransient(HardcoverOAuthError.invalidGrant))
  }

  func testAnswersThatCantBeReadAreNotRetried() {
    XCTAssertFalse(HardcoverService.isTransient(GraphQLClient.Error.noData))
    XCTAssertFalse(HardcoverService.isTransient(CancellationError()))
  }

  func testTheWaitDoublesUpToFiveMinutes() {
    XCTAssertEqual(SyncQueueService.hardcoverRetryDelay(afterAttempt: 1), 5)
    XCTAssertEqual(SyncQueueService.hardcoverRetryDelay(afterAttempt: 2), 10)
    XCTAssertEqual(SyncQueueService.hardcoverRetryDelay(afterAttempt: 3), 20)
    XCTAssertEqual(SyncQueueService.hardcoverRetryDelay(afterAttempt: 6), 160)
    XCTAssertEqual(SyncQueueService.hardcoverRetryDelay(afterAttempt: 7), 300)
    XCTAssertEqual(SyncQueueService.hardcoverRetryDelay(afterAttempt: 40), 300)
  }
}

/// A linked book's new whole percentage goes to the sync queue's Hardcover lane, not straight to
/// Hardcover, and an unlink empties the lane
class HardcoverProgressQueueingTests: XCTestCase {
  var sut: HardcoverService!
  var libraryService: LibraryServiceProtocolMock!
  var progress: PassthroughSubject<[String: Any], Never>!
  var queue: HardcoverQueueSpy!

  override func setUp() {
    progress = PassthroughSubject()
    libraryService = LibraryServiceProtocolMock()
    libraryService.metadataUpdatePublisher = Empty().eraseToAnyPublisher()
    libraryService.progressUpdatePublisher = progress.eraseToAnyPublisher()
    libraryService.getExternalResourcesForReturnValue = [
      SimpleExternalResource(
        providerName: ExternalResource.ProviderName.hardcover.rawValue,
        providerId: "12345",
        syncStatus: "synced",
        lastSyncedAt: nil
      )
    ]
    queue = HardcoverQueueSpy()

    /// Connected from the start, so `setup` starts tracking the library
    let keychain = KeychainServiceMock()
    try? keychain.set("hc_pat_abc123", key: .hardcoverToken)
    UserDefaults.sharedDefaults.set("42", forKey: Constants.UserDefaults.hardcoverUserId)
    sut = HardcoverService()
    sut.setup(
      libraryService: libraryService,
      syncService: SyncServiceProtocolMock(),
      keychain: keychain,
      progressQueue: queue
    )
  }

  override func tearDown() {
    UserDefaults.sharedDefaults.removeObject(forKey: Constants.UserDefaults.hardcoverUserId)
  }

  func testANewPercentageIsQueuedForTheLinkedBook() async {
    let queued = expectation(description: "queued")
    queue.onSchedule = { queued.fulfill() }

    progress.send(event(42))
    await fulfillment(of: [queued], timeout: 2)

    let task = queue.scheduled.first
    XCTAssertEqual(task?.uuid, "UUID")
    XCTAssertEqual(task?.relativePath, "book.m4b")
    XCTAssertEqual(task?.hardcoverBookId, 12345)
    XCTAssertEqual(task?.percent, 42)
  }

  func testTheSamePercentageIsQueuedOnce() async {
    let queued = expectation(description: "queued")
    queued.expectedFulfillmentCount = 2
    queue.onSchedule = { queued.fulfill() }

    progress.send(event(42))
    progress.send(event(42))
    progress.send(event(43))
    await fulfillment(of: [queued], timeout: 2)

    XCTAssertEqual(queue.scheduled.map(\.percent).sorted(), [42, 43])
  }

  func testTheStartAndTheEndAreNotQueued() async {
    let queued = expectation(description: "queued")
    queue.onSchedule = { queued.fulfill() }

    progress.send(event(0))
    progress.send(event(100))
    progress.send(event(5))
    await fulfillment(of: [queued], timeout: 2)

    XCTAssertEqual(queue.scheduled.map(\.percent), [5])
  }

  /// Only the external resource syncs: a link made on another device has no local
  /// `HardcoverBook` row, and its progress is still queued
  func testALinkSyncedFromAnotherDeviceIsQueuedWithoutALocalRow() async {
    libraryService.getHardcoverBookForReturnValue = nil
    let queued = expectation(description: "queued")
    queue.onSchedule = { queued.fulfill() }

    progress.send(event(42))
    await fulfillment(of: [queued], timeout: 2)

    XCTAssertEqual(queue.scheduled.first?.hardcoverBookId, 12345)
  }

  func testABookWithoutAHardcoverLinkIsNotQueued() async {
    libraryService.getExternalResourcesForReturnValue = [
      SimpleExternalResource(
        providerName: ExternalResource.ProviderName.jellyfin.rawValue,
        providerId: "abc",
        syncStatus: "synced",
        lastSyncedAt: nil
      )
    ]
    let queued = expectation(description: "queued")
    queued.isInverted = true
    queue.onSchedule = { queued.fulfill() }

    progress.send(event(42))
    await fulfillment(of: [queued], timeout: 0.5)
  }

  func testUnlinkingEmptiesTheLane() async {
    let cleared = expectation(description: "cleared")
    cleared.assertForOverFulfill = false
    queue.onClear = { cleared.fulfill() }

    await sut.disconnect()
    await fulfillment(of: [cleared], timeout: 2)
  }

  private func event(_ percent: Double) -> [String: Any] {
    ["relativePath": "book.m4b", "uuid": "UUID", "percentCompleted": percent]
  }
}

final class HardcoverQueueSpy: HardcoverProgressQueueing {
  struct Scheduled {
    let uuid: String
    let relativePath: String
    let hardcoverBookId: Int
    let percent: Double
  }

  private let lock = NSLock()
  private var _scheduled = [Scheduled]()
  var scheduled: [Scheduled] { lock.withLock { _scheduled } }
  var onSchedule: (() -> Void)?
  var onClear: (() -> Void)?

  func scheduleHardcoverProgress(uuid: String, relativePath: String, hardcoverBookId: Int, percentCompleted: Double) {
    lock.withLock {
      _scheduled.append(Scheduled(uuid: uuid, relativePath: relativePath, hardcoverBookId: hardcoverBookId, percent: percentCompleted))
    }
    onSchedule?()
  }

  func clearHardcoverProgress() async {
    onClear?()
  }
}

/// Hardcover's GraphQL API, answering each operation (`query ReadInProgress`, `mutation
/// InsertUserBook`, …) with the body set for it, and recording the variables of every request.
/// An operation without an answer gets a GraphQL error
private final class HardcoverAPIStub: URLProtocol {
  private static let lock = NSLock()
  private static var answers = [String: String]()
  private static var failures = [String: Int]()
  private static var requests = [(operation: String, variables: [String: Any])]()

  static func reset() {
    lock.withLock {
      answers = [:]
      failures = [:]
      requests = []
    }
  }

  /// Answers the operation with an HTTP error instead
  static func fail(_ operation: String, status: Int) {
    lock.withLock { failures[operation] = status }
  }

  static func answer(_ operation: String, with body: String) {
    lock.withLock { answers[operation] = body }
  }

  static func variables(of operation: String) -> [[String: Any]] {
    lock.withLock { requests.filter { $0.operation == operation }.map(\.variables) }
  }

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func stopLoading() {}

  override func startLoading() {
    let payload = (try? JSONSerialization.jsonObject(with: bodyData())) as? [String: Any]
    let query = payload?["query"] as? String ?? ""
    let operation = Self.operationName(in: query)

    let (answer, failure) = Self.lock.withLock {
      Self.requests.append((operation, payload?["variables"] as? [String: Any] ?? [:]))
      return (Self.answers[operation], Self.failures[operation])
    }
    let body = failure == nil ? answer ?? #"{"errors":[{"message":"not stubbed"}]}"# : "{}"

    let response = HTTPURLResponse(url: request.url!, statusCode: failure ?? 200, httpVersion: nil, headerFields: nil)!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Data(body.utf8))
    client?.urlProtocolDidFinishLoading(self)
  }

  /// The name after `query` or `mutation`
  private static func operationName(in query: String) -> String {
    let words = query.split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "_" })
    guard let keyword = words.firstIndex(where: { $0 == "query" || $0 == "mutation" }),
      words.index(after: keyword) < words.endIndex
    else { return "" }

    return String(words[words.index(after: keyword)])
  }

  /// URLSession hands a protocol the body as a stream
  private func bodyData() -> Data {
    if let body = request.httpBody { return body }
    guard let stream = request.httpBodyStream else { return Data() }

    stream.open()
    defer { stream.close() }

    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while stream.hasBytesAvailable {
      let count = stream.read(&buffer, maxLength: buffer.count)
      guard count > 0 else { break }
      data.append(buffer, count: count)
    }
    return data
  }
}
