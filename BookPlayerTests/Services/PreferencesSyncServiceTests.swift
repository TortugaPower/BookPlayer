//
//  PreferencesSyncServiceTests.swift
//  BookPlayerTests
//
//  Covers the resolver surface (effectiveSort/setSort/clearOverride),
//  SortLocation routing rules, and logout teardown.
//

@testable import BookPlayer
@testable import BookPlayerKit
import Combine
import RevenueCat
import XCTest

final class PreferencesSyncServiceTests: XCTestCase {
  // Each test gets its own UserDefaults suite so results don't bleed between tests.
  private var suiteName: String!
  private var defaults: UserDefaults!
  private var account: SyncToggleAccountStub!
  private var sut: PreferencesSyncService!

  override func setUp() {
    super.setUp()
    suiteName = "PreferencesSyncServiceTests.\(UUID().uuidString)"
    defaults = UserDefaults(suiteName: suiteName)!
    account = SyncToggleAccountStub(syncEnabled: false)

    sut = PreferencesSyncService()
    sut.setup(
      accountService: account,
      libraryService: LibraryServiceProtocolMock(),
      defaults: defaults,
      client: NetworkClientMock(mockedResponse: Empty())
    )
  }

  override func tearDown() {
    defaults.removePersistentDomain(forName: suiteName)
    sut = nil
    defaults = nil
    account = nil
    super.tearDown()
  }

  // MARK: - effectiveSort

  func testEffectiveSortReturnsCustomWhenNoValueStored() {
    XCTAssertEqual(sut.effectiveSort(forLocation: .libraryRoot), .custom)
    XCTAssertEqual(
      sut.effectiveSort(forLocation: .folder(LibraryItemRef(relativePath: "f", uuid: "real-uuid-1"))),
      .custom
    )
  }

  func testEffectiveSortReturnsCustomForUnresolvedLocation() {
    // Even if a stale value sits under a placeholder-UUID-derived key, an
    // `.unresolved` location maps to no key — so it always reads `.custom`.
    XCTAssertEqual(sut.effectiveSort(forLocation: .unresolved), .custom)
  }

  func testEffectiveSortRoundTripsAutomatic() {
    sut.setSort(.automatic(.metadataTitle), forLocation: .libraryRoot)
    XCTAssertEqual(sut.effectiveSort(forLocation: .libraryRoot), .automatic(.metadataTitle))
  }

  func testEffectiveSortRoundTripsCustom() {
    sut.setSort(.custom, forLocation: .libraryRoot)
    XCTAssertEqual(sut.effectiveSort(forLocation: .libraryRoot), .custom)
  }

  func testEffectiveSortIgnoresUnknownRawValueInStorage() {
    // Defensive: a malformed value left over from a future version or a
    // botched manual write must NOT crash; the resolver falls back to `.custom`.
    defaults.set("not-a-real-sort", forKey: Constants.UserDefaults.librarySortDefault)
    XCTAssertEqual(sut.effectiveSort(forLocation: .libraryRoot), .custom)
  }

  // MARK: - setSort routing

  func testSetSortLibraryRootWritesDefaultKey() {
    sut.setSort(.automatic(.fileName), forLocation: .libraryRoot)
    XCTAssertEqual(
      defaults.string(forKey: Constants.UserDefaults.librarySortDefault),
      SortType.fileName.rawValue
    )
  }

  func testSetSortFolderWritesUuidKey() {
    let uuid = "550e8400-e29b-41d4-a716-446655440000"
    sut.setSort(
      .automatic(.mostRecent),
      forLocation: .folder(LibraryItemRef(relativePath: "Folder A", uuid: uuid))
    )
    XCTAssertEqual(
      defaults.string(forKey: Constants.UserDefaults.librarySort(folderUuid: uuid)),
      SortType.mostRecent.rawValue
    )
    // Did not leak into the library-root key.
    XCTAssertNil(defaults.string(forKey: Constants.UserDefaults.librarySortDefault))
  }

  func testSetSortIsNoOpForUnresolved() {
    sut.setSort(.automatic(.metadataTitle), forLocation: .unresolved)
    // No write should have happened to either the default or any folder key.
    XCTAssertNil(defaults.string(forKey: Constants.UserDefaults.librarySortDefault))
    let domain = defaults.dictionaryRepresentation()
    XCTAssertFalse(domain.keys.contains(where: { $0.hasPrefix(Constants.UserDefaults.librarySortPrefix) }))
  }

  func testSetSortIsNoOpForFolderWithPlaceholderUuid() {
    // A `.folder` constructed with a placeholder UUID is a defensive guard:
    // even though `LibraryService.makeLocation` won't produce this, the
    // resolver re-checks and silently no-ops to keep a stale ref from
    // accidentally writing to the root or polluting storage.
    let placeholder = LibraryItemRef(
      relativePath: "Migrating",
      uuid: Constants.uuidPlaceholder
    )
    sut.setSort(.automatic(.metadataTitle), forLocation: .folder(placeholder))
    XCTAssertNil(defaults.string(forKey: Constants.UserDefaults.librarySortDefault))
    let domain = defaults.dictionaryRepresentation()
    XCTAssertFalse(domain.keys.contains(where: { $0.hasPrefix(Constants.UserDefaults.librarySortPrefix) }))
  }

  // MARK: - clearOverride

  func testClearOverrideRemovesFolderKey() {
    let uuid = "abc-123-real"
    let location = SortLocation.folder(LibraryItemRef(relativePath: "F", uuid: uuid))
    sut.setSort(.automatic(.metadataTitle), forLocation: location)
    XCTAssertNotNil(defaults.string(forKey: Constants.UserDefaults.librarySort(folderUuid: uuid)))

    sut.clearOverride(forLocation: location)

    XCTAssertNil(defaults.string(forKey: Constants.UserDefaults.librarySort(folderUuid: uuid)))
    XCTAssertEqual(sut.effectiveSort(forLocation: location), .custom)
  }

  // MARK: - handleLogout

  func testHandleLogoutWipesAllSortKeysAndDirtyList() {
    sut.setSort(.automatic(.metadataTitle), forLocation: .libraryRoot)
    sut.setSort(
      .automatic(.fileName),
      forLocation: .folder(LibraryItemRef(relativePath: "F", uuid: "uuid-1"))
    )
    // Seed the dirty list directly to verify it's wiped too.
    defaults.set(Data("{}".utf8), forKey: Constants.UserDefaults.userPreferencesDirty)

    sut.handleLogout()

    XCTAssertNil(defaults.string(forKey: Constants.UserDefaults.librarySortDefault))
    XCTAssertNil(defaults.string(forKey: Constants.UserDefaults.librarySort(folderUuid: "uuid-1")))
    XCTAssertNil(defaults.data(forKey: Constants.UserDefaults.userPreferencesDirty))
  }

  func testHandleLogoutLeavesUnrelatedKeysUntouched() {
    let unrelatedKey = "some_unrelated_pref"
    defaults.set("keep-me", forKey: unrelatedKey)
    sut.setSort(.automatic(.metadataTitle), forLocation: .libraryRoot)

    sut.handleLogout()

    XCTAssertEqual(defaults.string(forKey: unrelatedKey), "keep-me")
  }

  // MARK: - Dirty-list round-trip

  func testDirtyListPersistsAcrossInstances() async {
    // Local writes via setSort don't pass through KVO (they short-circuit on
    // value-unchanged); instead, simulate a real KVO-driven mutation by
    // writing directly to UD with the suite as defaults.
    //
    // We deliberately leave `account.syncEnabled = false` so `bootstrap()`'s
    // pull/flush short-circuit on `hasSyncEnabled()` — the shared
    // `NetworkClientMock(mockedResponse: Empty())` would force-cast `Empty`
    // to `PreferencesSyncResponse` and trap. KVO registration in bootstrap
    // happens regardless of sync state, which is all this test exercises.
    let key = Constants.UserDefaults.librarySortDefault

    // Trigger a KVO callback by writing through `defaults` itself. The
    // service registers an observer in `bootstrap()`, so we need to run that
    // first.
    await sut.bootstrap()
    defaults.set(SortType.metadataTitle.rawValue, forKey: key)

    // Give the KVO callback a tick to land + persist the dirty entry.
    try? await Task.sleep(nanoseconds: 50_000_000)

    // Verify the dirty list was written to UD.
    let persisted = defaults.data(forKey: Constants.UserDefaults.userPreferencesDirty)
    XCTAssertNotNil(persisted, "expected dirty list to be persisted after a tracked-key write")

    // A fresh instance pointed at the same defaults should rehydrate the
    // dirty entry on bootstrap. We can't read internal state, so the
    // observable proof is: a non-forced pull while the key is still dirty
    // (and the server returns the same value) leaves UD untouched. We test
    // this end-to-end via the LWW behavior in `testLwwLocalNewerSkipsServer`.
    // Here we just assert the persistence file shape.
    if let data = persisted,
       let raw = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
      XCTAssertNotNil(raw[key], "dirty list should contain the key that just changed")
      // Timestamp should be parseable as ISO8601 with fractional seconds.
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      XCTAssertNotNil(formatter.date(from: raw[key] ?? ""))
    } else {
      XCTFail("dirty list payload was not valid JSON [String:String]")
    }
  }

  // MARK: - Pull rate limit

  func testPullRateLimitSkipsWithinCooldown() async {
    account.syncEnabled = true
    let countingClient = CountingNetworkClient(
      response: makeServerResponse(entries: [
        ("library_sort:default", "metadataTitle", Date())
      ])
    )
    sut = PreferencesSyncService()
    sut.setup(
      accountService: account,
      libraryService: LibraryServiceProtocolMock(),
      defaults: defaults,
      client: countingClient
    )

    // Each pull issues a single nil-prefix request that fetches every
    // preference family in one round trip; the contract this test guards
    // is the rate limit, not the absolute count.
    await sut.pullFromServer(force: true) // succeeds, sets lastSuccessfulPull
    XCTAssertEqual(countingClient.requestCount, 1)

    // Within the cooldown window, a non-forced pull is a no-op (no network call).
    await sut.pullFromServer(force: false)
    XCTAssertEqual(countingClient.requestCount, 1)

    // A forced pull bypasses the cooldown.
    await sut.pullFromServer(force: true)
    XCTAssertEqual(countingClient.requestCount, 2)
  }

  func testPullSkipsWhenSyncDisabled() async {
    account.syncEnabled = false
    let countingClient = CountingNetworkClient(
      response: makeServerResponse(entries: [])
    )
    sut = PreferencesSyncService()
    sut.setup(
      accountService: account,
      libraryService: LibraryServiceProtocolMock(),
      defaults: defaults,
      client: countingClient
    )

    await sut.pullFromServer(force: true)
    // Even forced, no network call when sync is disabled (free / logged-out).
    XCTAssertEqual(countingClient.requestCount, 0)
  }

  // MARK: - LWW (last-write-wins)

  func testPullAppliesServerValueWhenNoLocalChange() async {
    account.syncEnabled = true
    sut = PreferencesSyncService()
    sut.setup(
      accountService: account,
      libraryService: LibraryServiceProtocolMock(),
      defaults: defaults,
      client: NetworkClientMock(mockedResponse: makeServerResponse(entries: [
        ("library_sort:default", "metadataTitle", Date())
      ]))
    )

    await sut.pullFromServer(force: true)

    XCTAssertEqual(
      sut.effectiveSort(forLocation: .libraryRoot),
      .automatic(.metadataTitle)
    )
  }

  func testPullSkipsServerEntryWithMalformedValue() async {
    // Malformed: missing the "sort" key. Without the validation guard this
    // would silently overwrite a good local pref with `""` → resolver maps
    // to `.custom`, losing user intent.
    account.syncEnabled = true
    sut.setSort(.automatic(.fileName), forLocation: .libraryRoot)

    let badJSON = """
    {"entries":[{"key":"library_sort:default","value":{"wrongKey":"oops"},"updated_at":"2030-01-01T00:00:00Z"}]}
    """
    let response = try! JSONDecoder().decode(
      PreferencesSyncResponse.self,
      from: Data(badJSON.utf8)
    )

    sut = PreferencesSyncService()
    sut.setup(
      accountService: account,
      libraryService: LibraryServiceProtocolMock(),
      defaults: defaults,
      client: NetworkClientMock(mockedResponse: response)
    )

    await sut.pullFromServer(force: true)

    // Local value is preserved.
    XCTAssertEqual(
      sut.effectiveSort(forLocation: .libraryRoot),
      .automatic(.fileName)
    )
  }

  // MARK: - Display prefs (Bool value shape)

  func testPullAppliesDisplayBoolValue() async {
    account.syncEnabled = true
    let response = makeRawServerResponse(rawEntries: [
      [
        "key": Constants.UserDefaults.libraryDisplayProgressStyle,
        "value": ["value": true],
        "updated_at": iso8601String(Date())
      ]
    ])

    sut = PreferencesSyncService()
    sut.setup(
      accountService: account,
      libraryService: LibraryServiceProtocolMock(),
      defaults: defaults,
      client: NetworkClientMock(mockedResponse: response)
    )

    await sut.pullFromServer(force: true)

    XCTAssertTrue(defaults.bool(forKey: Constants.UserDefaults.libraryDisplayProgressStyle))
  }

  func testPullAcceptsIntZeroOneAsBoolAndRejectsOtherTypes() async {
    // Two entries on display keys: one carries `Int 1` (must decode as
    // `true`), one carries a string (must be rejected, leaving the
    // pre-seeded local value intact). Without the type-specific branches
    // in `decodeServerValue`, a string value would either trap on
    // `defaults.set(_:forKey:)` or silently overwrite the local Bool.
    account.syncEnabled = true

    // Pre-seed the title-source key. The malformed pull entry must not
    // overwrite this.
    defaults.set(true, forKey: Constants.UserDefaults.libraryDisplayTitleSource)

    let response = makeRawServerResponse(rawEntries: [
      [
        "key": Constants.UserDefaults.libraryDisplayProgressStyle,
        "value": ["value": 1],
        "updated_at": iso8601String(Date())
      ],
      [
        "key": Constants.UserDefaults.libraryDisplayTitleSource,
        "value": ["value": "yes"],
        "updated_at": iso8601String(Date())
      ]
    ])

    sut = PreferencesSyncService()
    sut.setup(
      accountService: account,
      libraryService: LibraryServiceProtocolMock(),
      defaults: defaults,
      client: NetworkClientMock(mockedResponse: response)
    )

    await sut.pullFromServer(force: true)

    // Int 1 → true.
    XCTAssertTrue(defaults.bool(forKey: Constants.UserDefaults.libraryDisplayProgressStyle))
    // Malformed string → entry skipped, pre-seeded local value preserved.
    XCTAssertTrue(defaults.bool(forKey: Constants.UserDefaults.libraryDisplayTitleSource))
  }

  func testPullAppliesMixedPrefixEntries() async {
    // The pull issues a single nil-prefix request that returns every
    // preference family in one response. The per-entry dispatch in
    // `applyServerSnapshot` routes each entry to its schema's decoder
    // by key prefix — so a sort entry and a display entry can ride the
    // same response and both land correctly.
    //
    // The `sortContentsInByCallsCount` assertion guards against a
    // regression of the cross-prefix snapshot drift bug: with the
    // single-request pull, exactly ONE side-effect dispatch should
    // happen per applied sort key. A higher count would mean an entry
    // is being applied (and its side effect fired) more than once.
    account.syncEnabled = true

    let libraryServiceMock = LibraryServiceProtocolMock()

    let response = makeRawServerResponse(rawEntries: [
      [
        "key": Constants.UserDefaults.librarySortDefault,
        "value": ["sort": SortType.metadataTitle.rawValue],
        "updated_at": iso8601String(Date())
      ],
      [
        "key": Constants.UserDefaults.libraryDisplayProgressStyle,
        "value": ["value": true],
        "updated_at": iso8601String(Date())
      ]
    ])

    sut = PreferencesSyncService()
    sut.setup(
      accountService: account,
      libraryService: libraryServiceMock,
      defaults: defaults,
      client: NetworkClientMock(mockedResponse: response)
    )

    await sut.pullFromServer(force: true)

    XCTAssertEqual(
      sut.effectiveSort(forLocation: .libraryRoot),
      .automatic(.metadataTitle)
    )
    XCTAssertTrue(defaults.bool(forKey: Constants.UserDefaults.libraryDisplayProgressStyle))

    // Exactly one resort dispatch — for the sort entry. The display
    // entry's side effect is `.none`, so it should not contribute.
    XCTAssertEqual(libraryServiceMock.sortContentsInByCallsCount, 1)
  }

  func testPullRejectsIntOutsideBoolRange() async {
    // The display-prefix decoder accepts `Bool` directly and `Int 0/1`
    // as a JSON-coercion fallback. Anything else (e.g. `Int 2`) must be
    // rejected so a malformed server response can't silently overwrite
    // a good local value with a meaningless coercion.
    account.syncEnabled = true

    // Pre-seed local state — the malformed entry must leave it alone.
    defaults.set(true, forKey: Constants.UserDefaults.libraryDisplayProgressStyle)

    let response = makeRawServerResponse(rawEntries: [
      [
        "key": Constants.UserDefaults.libraryDisplayProgressStyle,
        "value": ["value": 2],
        "updated_at": iso8601String(Date())
      ]
    ])

    sut = PreferencesSyncService()
    sut.setup(
      accountService: account,
      libraryService: LibraryServiceProtocolMock(),
      defaults: defaults,
      client: NetworkClientMock(mockedResponse: response)
    )

    await sut.pullFromServer(force: true)

    XCTAssertTrue(defaults.bool(forKey: Constants.UserDefaults.libraryDisplayProgressStyle))
  }

  func testPullSkipsMalformedDisplayEntry() async {
    // Mirrors `testPullSkipsServerEntryWithMalformedValue` for the
    // display-prefix decoder: a payload missing the expected `value`
    // field (or carrying it under the wrong key) must be rejected so
    // a bad server response can't silently flip the local value.
    account.syncEnabled = true

    defaults.set(true, forKey: Constants.UserDefaults.libraryDisplayProgressStyle)

    let badJSON = """
    {"entries":[{"key":"library_display:progress_style","value":{"wrongField":false},"updated_at":"2030-01-01T00:00:00Z"}]}
    """
    let response = try! JSONDecoder().decode(
      PreferencesSyncResponse.self,
      from: Data(badJSON.utf8)
    )

    sut = PreferencesSyncService()
    sut.setup(
      accountService: account,
      libraryService: LibraryServiceProtocolMock(),
      defaults: defaults,
      client: NetworkClientMock(mockedResponse: response)
    )

    await sut.pullFromServer(force: true)

    // Local value preserved.
    XCTAssertTrue(defaults.bool(forKey: Constants.UserDefaults.libraryDisplayProgressStyle))
  }

  // MARK: - Helpers

  /// Builds a `PreferencesSyncResponse` from `(key, sortRaw, updatedAt)` tuples
  /// by round-tripping through JSON — exercises the actual decoder path so
  /// tests stay honest about the wire format.
  private func makeServerResponse(entries: [(String, String, Date)]) -> PreferencesSyncResponse {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let entryDicts: [[String: Any]] = entries.map { key, sort, date in
      [
        "key": key,
        "value": ["sort": sort],
        "updated_at": formatter.string(from: date)
      ]
    }
    let payload: [String: Any] = ["entries": entryDicts]
    let data = try! JSONSerialization.data(withJSONObject: payload)
    return try! JSONDecoder().decode(PreferencesSyncResponse.self, from: data)
  }

  /// Like `makeServerResponse(entries:)` but takes pre-built entry dicts.
  /// Use when the entry's `value` shape isn't sort-specific (e.g. display
  /// prefs use `{"value": <Bool>}`) or when you want to feed deliberately
  /// malformed payloads to the decoder.
  private func makeRawServerResponse(rawEntries: [[String: Any]]) -> PreferencesSyncResponse {
    let payload: [String: Any] = ["entries": rawEntries]
    let data = try! JSONSerialization.data(withJSONObject: payload)
    return try! JSONDecoder().decode(PreferencesSyncResponse.self, from: data)
  }

  private func iso8601String(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
  }
}

// MARK: - Test stubs

/// `NetworkClientMock` that counts how many `request` calls it serviced — used
/// to verify the pull rate limit suppresses redundant calls without resorting
/// to timing-based tests.
private final class CountingNetworkClient: NetworkClientProtocol {
  private(set) var requestCount = 0
  let response: Decodable

  init(response: Decodable) {
    self.response = response
  }

  func request<T: Decodable>(
    url: URL,
    method: HTTPMethod,
    parameters: [String: Any]?,
    useKeychain: Bool
  ) async throws -> T {
    requestCount += 1
    // swiftlint:disable:next force_cast
    return response as! T
  }

  func request<T: Decodable>(
    path: String,
    method: HTTPMethod,
    parameters: [String: Any]?
  ) async throws -> T {
    requestCount += 1
    // swiftlint:disable:next force_cast
    return response as! T
  }

  // The rest are no-ops; the pull path only uses `request`.
  func upload(_ data: Data, remoteURL: URL) async throws {}
  func uploadTask(
    _ fileURL: URL,
    remoteURL: URL,
    taskDescription: String?,
    session: URLSession
  ) async -> URLSessionTask {
    session.uploadTask(with: URLRequest(url: URL(string: "https://example.com")!), from: Data())
  }
  func upload(
    _ fileURL: URL,
    remoteURL: URL,
    identifier: String,
    method: HTTPMethod
  ) async throws -> (Data, URLResponse) {
    (Data(), URLResponse())
  }
  func download(url: URL, delegate: BPTaskDownloadDelegate) {}
  func download(url: URL, taskDescription: String?, session: URLSession) async -> URLSessionTask {
    URLSession.shared.downloadTask(with: URLRequest(url: URL(string: "https://example.com")!))
  }
  func download(request: URLRequest, taskDescription: String?, session: URLSession) async -> URLSessionTask {
    URLSession.shared.downloadTask(with: request)
  }
}

/// Inline `AccountServiceProtocol` stub that lets each test flip
/// `hasSyncEnabled()` independently. The shared `AccountServiceMock` returns
/// a fixed `false`, which is fine for most tests but useless when we need to
/// pretend the user is on a Pro account.
private final class SyncToggleAccountStub: AccountServiceProtocol {
  var syncEnabled: Bool

  init(syncEnabled: Bool) {
    self.syncEnabled = syncEnabled
  }

  func hasSyncEnabled() -> Bool { syncEnabled }
  func hasPlusAccess() -> Bool { syncEnabled }
  func hasAccount() -> Bool { false }
  func getAccountId() -> String? { nil }
  func getAccount() -> Account? { nil }
  func getAnonymousId() -> String? { nil }
  func createAccount(donationMade: Bool) -> Account { Account() }
  func updateAccount(from customerInfo: CustomerInfo) {}
  func updateAccount(id: String?, email: String?, donationMade: Bool?, hasSubscription: Bool?) {}
  func setDelegate(_ delegate: PurchasesDelegate) {}
  func loginIfUserExists(delegate: PurchasesDelegate) {}
  func login(with token: String, userId: String) async throws -> Account? { nil }
  func loginTestAccount(token: String) async throws {}
  func loginWithTransferredCredentials(
    token: String,
    accountId: String,
    email: String,
    hasSubscription: Bool,
    donationMade: Bool
  ) async throws -> Account? { nil }
  func handlePasskeyLogin(response: PasskeyLoginResponse) async throws {}
  func getHardcodedSubscriptionOptions() -> [PricingModel] { [] }
  func getSubscriptionOptions() async throws -> [PricingModel] { [] }
  func getSecondOnboarding<T: Decodable>() async throws -> T { throw BookPlayerError.cancelledTask }
  func subscribe(option: PricingModel) async throws -> Bool { false }
  func subscribe(option: PricingOption) async throws -> Bool { false }
  func restorePurchases() async throws -> CustomerInfo { try await Purchases.shared.customerInfo() }
  func logout() throws {}
  func deleteAccount() async throws -> String { "" }
  func getAccessLevel() -> BookPlayerKit.AccessLevel {
    return .plus
  }
}
