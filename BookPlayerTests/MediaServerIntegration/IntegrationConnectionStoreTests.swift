//
//  IntegrationConnectionStoreTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

@testable import BookPlayer
@testable import BookPlayerKit
import XCTest

@MainActor
final class IntegrationConnectionStoreTests: XCTestCase {
  private var keychain: KeychainServiceMock!
  private var defaults: UserDefaults!
  private var suiteName: String!
  private var sut: IntegrationConnectionStore<AudiobookShelfConnectionData>!

  override func setUp() {
    super.setUp()
    keychain = KeychainServiceMock()
    suiteName = "IntegrationConnectionStoreTests.\(UUID().uuidString)"
    defaults = UserDefaults(suiteName: suiteName)
    sut = IntegrationConnectionStore(
      keychainKey: .audiobookshelfConnection,
      activeIDDefaultsKey: "test_active_id",
      keychain: keychain,
      defaults: defaults
    )
  }

  override func tearDown() {
    defaults.removePersistentDomain(forName: suiteName)
    keychain = nil
    defaults = nil
    sut = nil
    super.tearDown()
  }

  // MARK: - Helpers

  private func makeConnection(
    id: String = UUID().uuidString,
    url: String = "https://abs.example.com",
    userID: String = "user-1",
    token: String = "token-1",
    selectedLibraryId: String? = nil
  ) -> AudiobookShelfConnectionData {
    AudiobookShelfConnectionData(
      id: id,
      url: URL(string: url)!,
      serverName: "Test Server",
      userID: userID,
      userName: "tester",
      apiToken: token,
      selectedLibraryId: selectedLibraryId
    )
  }

  // MARK: - Re-auth against a moved server

  /// The store half of the moved-server contract, pinned here because the Jellyfin service has no
  /// injectable network seam to drive it end-to-end the way the AudiobookShelf VM tests do.
  func testUpsertReplacingIDUpdatesTheRowWhenTheURLChanged() {
    sut.upsert(url: URL(string: "https://old.example.com")!, userID: "user-1") { _ in
      self.makeConnection(id: "a", url: "https://old.example.com", selectedLibraryId: "lib-9")
    }

    let result = sut.upsert(
      url: URL(string: "https://moved.example.com")!,
      userID: "user-1",
      replacingID: "a"
    ) { existing in
      self.makeConnection(
        id: existing?.id ?? UUID().uuidString,
        url: "https://moved.example.com",
        selectedLibraryId: existing?.selectedLibraryId
      )
    }

    XCTAssertEqual(result.replaced?.id, "a", "the account match finds nothing; replacingID must")
    XCTAssertEqual(sut.connections.count, 1, "the old-URL row must not survive as an orphan")
    XCTAssertEqual(sut.connections.first?.id, "a", "outbound references survive the move")
    XCTAssertEqual(sut.connections.first?.selectedLibraryId, "lib-9", "library selection survives")
  }

  /// A different account is genuinely a new connection, not a moved server — the old row stays.
  func testUpsertReplacingIDRefusesADifferentAccount() {
    sut.upsert(url: URL(string: "https://old.example.com")!, userID: "user-1") { _ in
      self.makeConnection(id: "a", url: "https://old.example.com")
    }

    sut.upsert(
      url: URL(string: "https://moved.example.com")!,
      userID: "someone-else",
      replacingID: "a"
    ) { existing in
      XCTAssertNil(existing, "a different userID must not inherit the old row's identity")
      return self.makeConnection(id: "b", url: "https://moved.example.com", userID: "someone-else")
    }

    XCTAssertEqual(sut.connections.count, 2, "signing into a different account forks, by design")
  }

  // MARK: - Loading

  func testReloadLoadsStoredConnectionsAndActivatesTheFirst() throws {
    let stored = [makeConnection(id: "a"), makeConnection(id: "b", userID: "user-2")]
    try keychain.set(stored, key: .audiobookshelfConnection)

    sut.reload()

    XCTAssertEqual(sut.connections.map(\.id), ["a", "b"])
    XCTAssertEqual(sut.activeConnectionID, "a")
  }

  func testReloadMigratesTheSingleConnectionFormat() throws {
    // Records written before multi-server support were a bare object, not an array.
    try keychain.set(makeConnection(id: "legacy"), key: .audiobookshelfConnection)

    sut.reload()

    XCTAssertEqual(sut.connections.map(\.id), ["legacy"])
    XCTAssertEqual(sut.activeConnectionID, "legacy")
    // And it must be rewritten in the new shape, so the migration only happens once.
    let rewritten: [AudiobookShelfConnectionData]? = try keychain.get(.audiobookshelfConnection)
    XCTAssertEqual(rewritten?.count, 1)
  }

  func testReloadDropsRecordsMissingATokenOrUser() throws {
    let stored = [
      makeConnection(id: "good"),
      makeConnection(id: "no-token", userID: "user-2", token: ""),
      makeConnection(id: "no-user", userID: ""),
    ]
    try keychain.set(stored, key: .audiobookshelfConnection)

    sut.reload()

    // A record with no token can't authenticate, so keeping it would only produce 401 loops.
    XCTAssertEqual(sut.connections.map(\.id), ["good"])
  }

  func testReloadPreservesAPersistedActiveSelection() throws {
    try keychain.set(
      [makeConnection(id: "a"), makeConnection(id: "b", userID: "user-2")],
      key: .audiobookshelfConnection
    )
    defaults.set("b", forKey: "test_active_id")

    sut.reload()

    // Regression guard: seeding from defaults must happen before normalization, or the user's chosen
    // server silently resets to the first one on every launch.
    XCTAssertEqual(sut.activeConnectionID, "b")
    XCTAssertEqual(sut.active?.id, "b")
  }

  func testReloadRepointsAStaleActiveSelection() throws {
    try keychain.set([makeConnection(id: "a")], key: .audiobookshelfConnection)
    defaults.set("deleted-elsewhere", forKey: "test_active_id")

    sut.reload()

    XCTAssertEqual(sut.activeConnectionID, "a")
  }

  // MARK: - Upsert

  func testUpsertPreservesIdAndSelectedLibraryOnReauth() {
    let url = URL(string: "https://abs.example.com")!
    sut.upsert(url: url, userID: "user-1") { _ in
      self.makeConnection(id: "original", token: "old", selectedLibraryId: "lib-7")
    }

    let result = sut.upsert(url: url, userID: "user-1") { existing in
      self.makeConnection(
        id: existing?.id ?? "regenerated",
        token: "new",
        selectedLibraryId: existing?.selectedLibraryId
      )
    }

    XCTAssertEqual(sut.connections.count, 1, "re-auth must replace, not accumulate")
    XCTAssertEqual(result.saved.id, "original", "connection id must survive re-auth")
    XCTAssertEqual(result.saved.selectedLibraryId, "lib-7", "library context must survive re-auth")
    XCTAssertEqual(result.replaced?.apiToken, "old", "caller needs the old token to revoke it")
  }

  func testUpsertTreatsCanonicallyEqualURLsAsTheSameAccount() {
    sut.upsert(url: URL(string: "https://abs.example.com")!, userID: "user-1") { _ in
      self.makeConnection(id: "first", url: "https://abs.example.com")
    }
    sut.upsert(url: URL(string: "https://abs.example.com:443/")!, userID: "user-1") { existing in
      self.makeConnection(id: existing?.id ?? "second", url: "https://abs.example.com:443/")
    }

    // Trailing slash and default port are the same server; two rows here would mean duplicate
    // connections for one account.
    XCTAssertEqual(sut.connections.count, 1)
    XCTAssertEqual(sut.connections.first?.id, "first")
  }

  func testUpsertKeepsSeparateAccountsOnTheSameServer() {
    let url = URL(string: "https://abs.example.com")!
    sut.upsert(url: url, userID: "user-1") { _ in self.makeConnection(id: "a", userID: "user-1") }
    sut.upsert(url: url, userID: "user-2") { _ in self.makeConnection(id: "b", userID: "user-2") }

    XCTAssertEqual(sut.connections.count, 2)
    XCTAssertEqual(sut.activeConnectionID, "b", "the newest sign-in becomes active")
  }

  func testUpsertPersistsThroughTheKeychain() throws {
    sut.upsert(url: URL(string: "https://abs.example.com")!, userID: "user-1") { _ in
      self.makeConnection(id: "a")
    }

    let persisted: [AudiobookShelfConnectionData]? = try keychain.get(.audiobookshelfConnection)
    XCTAssertEqual(persisted?.map(\.id), ["a"])
  }

  // MARK: - Active selection

  func testSetActiveIgnoresAnUnknownID() {
    sut.upsert(url: URL(string: "https://abs.example.com")!, userID: "user-1") { _ in
      self.makeConnection(id: "a")
    }

    XCTAssertFalse(sut.setActive(id: "nope"))
    XCTAssertEqual(sut.activeConnectionID, "a")
  }

  func testSetActivePersistsAcrossAFreshStore() {
    let url = URL(string: "https://abs.example.com")!
    sut.upsert(url: url, userID: "user-1") { _ in self.makeConnection(id: "a", userID: "user-1") }
    sut.upsert(url: url, userID: "user-2") { _ in self.makeConnection(id: "b", userID: "user-2") }

    XCTAssertTrue(sut.setActive(id: "a"))

    // A new store over the same backing stores must observe the same choice — this is what breaks if
    // the observable value and UserDefaults drift apart.
    let reopened = IntegrationConnectionStore<AudiobookShelfConnectionData>(
      keychainKey: .audiobookshelfConnection,
      activeIDDefaultsKey: "test_active_id",
      keychain: keychain,
      defaults: defaults
    )
    reopened.reload()
    XCTAssertEqual(reopened.activeConnectionID, "a")
  }

  // MARK: - Removal

  func testRemoveReturnsTheDroppedRecordForTeardown() {
    sut.upsert(url: URL(string: "https://abs.example.com")!, userID: "user-1") { _ in
      self.makeConnection(id: "a", token: "revoke-me")
    }

    let removed = sut.remove(id: "a")

    // The caller needs this to revoke the token server-side.
    XCTAssertEqual(removed?.apiToken, "revoke-me")
    XCTAssertTrue(sut.connections.isEmpty)
  }

  func testRemovingTheLastConnectionClearsTheKeychainEntry() throws {
    sut.upsert(url: URL(string: "https://abs.example.com")!, userID: "user-1") { _ in
      self.makeConnection(id: "a")
    }

    sut.remove(id: "a")

    // Leaving an empty array behind would make the next launch look like a configured integration.
    XCTAssertNil(keychain.entries[.audiobookshelfConnection])
    XCTAssertNil(sut.activeConnectionID)
  }

  func testRemovingTheActiveConnectionPromotesAnother() {
    let url = URL(string: "https://abs.example.com")!
    sut.upsert(url: url, userID: "user-1") { _ in self.makeConnection(id: "a", userID: "user-1") }
    sut.upsert(url: url, userID: "user-2") { _ in self.makeConnection(id: "b", userID: "user-2") }
    XCTAssertEqual(sut.activeConnectionID, "b")

    sut.remove(id: "b")

    XCTAssertEqual(sut.activeConnectionID, "a")
    XCTAssertEqual(sut.active?.id, "a")
  }

  func testRemoveIgnoresAnUnknownID() {
    sut.upsert(url: URL(string: "https://abs.example.com")!, userID: "user-1") { _ in
      self.makeConnection(id: "a")
    }

    XCTAssertNil(sut.remove(id: "nope"))
    XCTAssertEqual(sut.connections.count, 1)
  }

  // MARK: - Field updates

  func testUpdateCustomHeadersPersistsAndReportsSuccess() throws {
    sut.upsert(url: URL(string: "https://abs.example.com")!, userID: "user-1") { _ in
      self.makeConnection(id: "a")
    }

    XCTAssertTrue(sut.updateCustomHeaders(id: "a", ["CF-Access-Client-Id": "abc"]))
    XCTAssertFalse(sut.updateCustomHeaders(id: "nope", [:]))

    let persisted: [AudiobookShelfConnectionData]? = try keychain.get(.audiobookshelfConnection)
    XCTAssertEqual(persisted?.first?.customHeaders, ["CF-Access-Client-Id": "abc"])
  }

  func testSetSelectedLibraryPersists() throws {
    sut.upsert(url: URL(string: "https://abs.example.com")!, userID: "user-1") { _ in
      self.makeConnection(id: "a")
    }

    XCTAssertTrue(sut.setSelectedLibrary(id: "a", libraryId: "lib-3"))

    let persisted: [AudiobookShelfConnectionData]? = try keychain.get(.audiobookshelfConnection)
    XCTAssertEqual(persisted?.first?.selectedLibraryId, "lib-3")
  }
}
