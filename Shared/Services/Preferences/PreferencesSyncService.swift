//
//  PreferencesSyncService.swift
//  BookPlayer
//
//  Watches App-Group UserDefaults via per-key KVO, batches local changes
//  to the backend, and applies remote changes in. Source of truth is
//  UserDefaults itself; this service is a passive observer + sync coordinator.
//

import Combine
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// sourcery: AutoMockable
public protocol PreferencesSyncServiceProtocol: SortPreferencesResolving {
  /// Fires whenever a tracked key's value changes (locally or via pull).
  /// Subscribers get the changed key.
  var preferencesChanged: PassthroughSubject<String, Never> { get }

  /// Bootstrap on app launch / login: register library-default observer,
  /// load persisted dirty list, and pull from server.
  func bootstrap() async

  /// Lazy-register a folder-override observer (called from `ItemListView.onAppear`).
  /// Idempotent.
  func register(folderUuid: String)

  /// Fetches the latest preferences from the server.
  ///
  /// Rate-limited to one successful pull per 30s unless `force` is true.
  func pullFromServer(force: Bool) async

  /// Tear down: cancel pending flush, drop dirty list, remove observers,
  /// clear all `library_sort:*` UserDefaults keys.
  func handleLogout()
}

@Observable
public final class PreferencesSyncService: NSObject, PreferencesSyncServiceProtocol, BPLogger {
  // MARK: - Public

  public let preferencesChanged = PassthroughSubject<String, Never>()

  // MARK: - Dependencies (assigned by `setup(...)` — IUO matches the
  // pattern used by `LibraryService`, `SyncService`, etc., where the
  // env-value default `.init()` produces a placeholder shell that gets
  // wired up before any view actually invokes a method on it.)

  private var accountService: AccountServiceProtocol!
  private var libraryService: LibraryServiceProtocol!
  private var defaults: UserDefaults!
  private var provider: NetworkProvider<PreferencesAPI>!

  // MARK: - State

  /// Single source of truth for every synced preference family. Each entry
  /// owns its prefix, the static keys observed at bootstrap, the value-shape
  /// codec used by `applyServerSnapshot` / `flush`, and the side effect to
  /// run after a remote-pulled value lands in `UserDefaults`.
  ///
  /// Adding a new family (e.g. `audio_eq:`) is a single entry append: declare
  /// the prefix + keys in `Constants.UserDefaults`, plug the decode/encode
  /// closures, and pick a `PreferenceSideEffect` (or extend the enum if a new
  /// kind of side effect is needed).
  private let schemas: [PreferenceSchema] = [
    PreferenceSchema(
      prefix: Constants.UserDefaults.librarySortPrefix,
      staticKeys: [Constants.UserDefaults.librarySortDefault],
      decode: { value in
        guard
          let stringValue = value["sort"]?.value as? String,
          EffectiveSort(rawValue: stringValue) != nil
        else { return nil }
        return stringValue
      },
      encode: { key, defaults in
        ["sort": defaults.string(forKey: key) ?? ""]
      },
      sideEffect: .resort
    ),
    PreferenceSchema(
      prefix: Constants.UserDefaults.libraryDisplayPrefix,
      staticKeys: [
        Constants.UserDefaults.libraryDisplayProgressStyle,
        Constants.UserDefaults.libraryDisplayTitleSource,
      ],
      decode: { value in
        // Accept both real `Bool` and `Int 0/1` since JSON serializers
        // sometimes collapse Booleans to integers.
        if let boolValue = value["value"]?.value as? Bool {
          return boolValue
        }
        if let intValue = value["value"]?.value as? Int, intValue == 0 || intValue == 1 {
          return intValue == 1
        }
        return nil
      },
      encode: { key, defaults in
        ["value": defaults.bool(forKey: key)]
      },
      sideEffect: .none
    ),
  ]

  /// Prefixes the service tracks, derived from `schemas`. Used by the
  /// pull loop and by `handleLogout`'s wipe sweep.
  private var trackedPrefixes: [String] {
    schemas.map(\.prefix)
  }

  /// Static (non-prefixed) tracked keys, derived from `schemas`. Used at
  /// bootstrap to register KVO observers eagerly.
  private var staticTrackedKeys: [String] {
    schemas.flatMap(\.staticKeys)
  }

  /// Looks up the schema that owns `key` (by prefix match). Returns `nil`
  /// for keys outside the tracked families.
  private func schema(forKey key: String) -> PreferenceSchema? {
    schemas.first { key.hasPrefix($0.prefix) }
  }

  /// Currently registered KVO key paths.
  private var registeredKeys: Set<String> = []

  /// Keys awaiting server flush, with the timestamp of the local change.
  /// Persisted to `userPreferences.dirty` synchronously on every mutation.
  private var dirty: [String: Date] = [:]

  /// Minimum interval between non-forced pulls. Forced pulls (login, foreground,
  /// sync-enabled flip) bypass this gate.
  private static let pullCooldown: TimeInterval = 30

  /// Debounce window for batched server flushes. Reset on each new dirty key
  /// so a burst of changes coalesces into a single PATCH.
  private static let flushDebounce: TimeInterval = 3

  /// Last successful pull timestamp; gates `pullFromServer(force: false)`.
  private var lastSuccessfulPull: Date?

  /// Set during `applyServerSnapshot` to suppress KVO echoes.
  private var isApplyingRemoteUpdate = false

  /// Pending debounced flush.
  private var flushTask: Task<Void, Never>?

  /// Concurrency lock guarding `dirty`, `registeredKeys`, `flushTask`,
  /// `lastSuccessfulPull`, `isApplyingRemoteUpdate`. KVO callbacks fire
  /// on the calling thread; foreground/login signals come on main; pull
  /// runs in a Task. Access is serialized via this queue.
  private let lock = NSRecursiveLock()

  /// Account-state and lifecycle observers (logout, accountUpdate, foreground).
  private var notificationObservers: [NSObjectProtocol] = []

  // MARK: - Init / setup

  public override init() {
    super.init()
  }

  /// Wires up dependencies. Called once by `AppServices` after the surrounding
  /// services are constructed. Until this fires, all methods that hit the
  /// network or UserDefaults will trap on the IUOs above — but the env-value
  /// default `.init()` is never exposed to view code: by the time any view
  /// reads `@Environment(\.preferencesService)`, `MainCoordinator` has
  /// already injected the configured instance.
  public func setup(
    accountService: AccountServiceProtocol,
    libraryService: LibraryServiceProtocol,
    defaults: UserDefaults = UserDefaults(suiteName: Constants.ApplicationGroupIdentifier) ?? .standard,
    client: NetworkClientProtocol = NetworkClient()
  ) {
    self.accountService = accountService
    self.libraryService = libraryService
    self.defaults = defaults
    self.provider = NetworkProvider<PreferencesAPI>(client: client)
  }

  deinit {
    // No lock needed: deinit implies refcount=0, so no other thread can be
    // mid-`observeValue` against `self` (KVO callbacks are synchronous to the
    // writing thread and require a live reference). Cleanup of in-session
    // state goes through `teardown()` on the `.logout` path; this is the
    // belt-and-suspenders cleanup at process exit.
    if let defaults {
      for key in registeredKeys {
        defaults.removeObserver(self, forKeyPath: key)
      }
    }
    for token in notificationObservers {
      NotificationCenter.default.removeObserver(token)
    }
  }

  // MARK: - Lifecycle

  public func bootstrap() async {
    lock.lock()
    loadPersistedDirtyList()
    for key in staticTrackedKeys {
      addObserver(forKey: key)
    }
    if notificationObservers.isEmpty {
      registerNotificationObservers()
    }
    lock.unlock()

    await pullFromServer(force: true)

    // Drain any persisted dirty entries left over from a previous session
    // (e.g. process killed mid-debounce). `flush` no-ops on empty/sync-disabled
    // and respects the LWW-driven dirty-list cleanup that pullFromServer just
    // performed, so this is safe to run unconditionally.
    await flush()
  }

  /// Wire `.logout` (clean up state for the next user) and `.accountUpdate`
  /// (login / subscription state change → re-pull to fetch the new user's prefs
  /// or the prefs gated behind `hasSyncEnabled()`).
  private func registerNotificationObservers() {
    let logoutToken = NotificationCenter.default.addObserver(
      forName: .logout,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.handleLogout()
    }
    notificationObservers.append(logoutToken)

    let accountToken = NotificationCenter.default.addObserver(
      forName: .accountUpdate,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      guard let self else { return }
      // `AccountService.logout()` calls `updateAccount(id: "", ...)` BEFORE
      // posting `.logout`, which means `.accountUpdate` fires first with an
      // empty account id. Without this guard we'd re-run `bootstrap()` against
      // the about-to-be-torn-down service and re-register KVO observers that
      // `handleLogout` would have to clean up again — and any sticky-sort
      // change after that point could leak into the next account that signs in.
      guard self.accountService.getAccountId() != nil else { return }
      // Re-run the full bootstrap path on every account state change. This
      // covers logout→login (where `handleLogout` removed all KVO observers
      // and we need to re-register the static keys) as well as free→Pro
      // upgrades (where the rate-limited pull would otherwise have run).
      // `bootstrap()` is idempotent: dirty-list reload reads the persisted
      // file (empty if logout just wiped it), KVO `addObserver` is guarded
      // by `registeredKeys`, and the notification-observer setup is guarded
      // by `notificationObservers.isEmpty`. Bootstrap also drains pending
      // dirty entries via its own `flush()` call.
      Task { [weak self] in
        await self?.bootstrap()
      }
    }
    notificationObservers.append(accountToken)

    #if os(iOS)
    let foregroundToken = NotificationCenter.default.addObserver(
      forName: UIApplication.willEnterForegroundNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { [weak self] in
        await self?.pullFromServer(force: true)
      }
    }
    notificationObservers.append(foregroundToken)
    #endif
  }

  public func register(folderUuid: String) {
    guard Constants.isRealUuid(folderUuid) else { return }
    let key = Constants.UserDefaults.librarySort(folderUuid: folderUuid)
    lock.lock()
    addObserver(forKey: key)
    lock.unlock()
  }

  public func handleLogout() {
    lock.lock()
    defer { lock.unlock() }

    flushTask?.cancel()
    flushTask = nil
    dirty.removeAll()
    lastSuccessfulPull = nil

    for key in registeredKeys {
      defaults.removeObserver(self, forKeyPath: key)
    }
    registeredKeys.removeAll()

    // Wipe all sticky-sort keys + the dirty list key.
    let domain = defaults.dictionaryRepresentation()
    for (key, _) in domain {
      for prefix in trackedPrefixes where key.hasPrefix(prefix) {
        defaults.removeObject(forKey: key)
      }
    }
    defaults.removeObject(forKey: Constants.UserDefaults.userPreferencesDirty)
  }

  // MARK: - SortPreferencesResolving

  public func effectiveSort(forLocation location: SortLocation) -> EffectiveSort {
    guard let key = userDefaultsKey(forLocation: location) else { return .custom }

    guard
      let raw = defaults.string(forKey: key),
      !raw.isEmpty,
      let parsed = EffectiveSort(rawValue: raw)
    else {
      return .custom
    }
    return parsed
  }

  public func setSort(_ value: EffectiveSort, forLocation location: SortLocation) {
    guard let key = userDefaultsKey(forLocation: location) else { return }
    let newRaw = value.rawValue
    if defaults.string(forKey: key) == newRaw { return }
    defaults.set(newRaw, forKey: key)
  }

  /// Removes the local override for a location. **Currently unused in production**
  /// (only exercised by tests).
  ///
  /// ⚠️ Before wiring this to the UI: today the KVO-driven flush serializes the
  /// post-removal value as `""` and would PATCH that to the server instead of
  /// issuing a delete. `applyServerSnapshot` rejects `""` so the server-side row
  /// would persist; another device pulling next would resurrect the override.
  /// Wire `PreferencesAPI.deletePreferences` here (or via a tombstone semantic
  /// in the dirty list) before exposing this to user actions.
  public func clearOverride(forLocation location: SortLocation) {
    guard let key = userDefaultsKey(forLocation: location) else { return }
    defaults.removeObject(forKey: key)
  }

  /// Maps a `SortLocation` to the UserDefaults key it should read/write.
  /// Returns `nil` for `.unresolved` so callers no-op cleanly.
  private func userDefaultsKey(forLocation location: SortLocation) -> String? {
    switch location {
    case .libraryRoot:
      return Constants.UserDefaults.librarySortDefault
    case .folder(let ref):
      // Defensive: even though `.folder` should only be constructed with real UUIDs,
      // re-check here so a malformed caller can never accidentally hit the root key.
      guard Constants.isRealUuid(ref.uuid) else { return nil }
      return Constants.UserDefaults.librarySort(folderUuid: ref.uuid)
    case .unresolved:
      return nil
    }
  }

  // MARK: - Server pull

  public func pullFromServer(force: Bool = false) async {
    guard accountService.hasSyncEnabled() else { return }

    lock.lock()
    if !force, let last = lastSuccessfulPull, Date().timeIntervalSince(last) < Self.pullCooldown {
      lock.unlock()
      return
    }
    lock.unlock()

    // One request per tracked prefix. Each prefix has its own value-shape
    // decoder; partitioning at the request level keeps the per-prefix
    // before-snapshot tight (only those keys' values are captured) and
    // avoids cross-contaminating value-shape validation in `applyServerSnapshot`.
    var anyRequestSucceeded = false
    for prefix in trackedPrefixes {
      let response: PreferencesSyncResponse
      do {
        response = try await provider.request(.getPreferences(prefix: prefix))
      } catch {
        Self.logger.trace("PreferencesSyncService.pullFromServer failed for prefix \(prefix): \(error.localizedDescription)")
        continue
      }
      anyRequestSucceeded = true

      let beforeSnapshot = currentValues(forPrefix: prefix)
      let appliedKeys = applyServerSnapshot(response.entries)

      // Walk applied keys and run the per-prefix side effect (resort for
      // sort keys, no-op for display keys). For each key whose value
      // actually changed, emit `preferencesChanged` so subscribers (e.g.
      // `ItemListView`) can refresh. The KVO observer doesn't publish here
      // because `applyServerSnapshot` sets `isApplyingRemoteUpdate` to
      // suppress echo loops.
      for key in appliedKeys {
        let oldValue = beforeSnapshot[key]
        let newValue = currentValue(forKey: key)
        if oldValue == newValue { continue }
        await dispatchSideEffect(forKey: key)
        preferencesChanged.send(key)
      }
    }

    // Only update the cooldown timestamp if at least one prefix request
    // succeeded — otherwise we'd suppress retries after a transient failure.
    if anyRequestSucceeded {
      lock.lock()
      lastSuccessfulPull = Date()
      lock.unlock()
    }
  }

  // MARK: - KVO

  // swiftlint:disable:next block_based_kvo
  public override func observeValue(
    forKeyPath keyPath: String?,
    of object: Any?,
    change: [NSKeyValueChangeKey: Any]?,
    context: UnsafeMutableRawPointer?
  ) {
    // Capture the key to publish under the lock, then release before
    // invoking subscribers and rescheduling. `preferencesChanged.send`
    // runs subscriber closures synchronously; holding the lock during
    // that creates a lock-ordering hazard for any subscriber that takes
    // its own locks.
    let changedKey: String
    lock.lock()
    do {
      defer { lock.unlock() }

      guard !isApplyingRemoteUpdate, let key = keyPath else { return }
      // Use `String(describing:)` so the equality guard works regardless of
      // the underlying type (sort keys store `String`, display keys store
      // `Bool` via `NSNumber`). A typed cast to `String` would collapse
      // every Bool change into `"" != ""`, silently dropping the dirty mark.
      let oldValue = change?[.oldKey].map { String(describing: $0) } ?? ""
      let newValue = change?[.newKey].map { String(describing: $0) } ?? ""
      guard oldValue != newValue else { return }

      dirty[key] = Date()
      persistDirtyList()
      changedKey = key
    }
    preferencesChanged.send(changedKey)
    scheduleFlush()
  }

  // MARK: - Private

  /// Registers KVO for a single App Group key. KVO on `UserDefaults` is
  /// **per-process**: writes from another process (extensions, watch, widgets)
  /// hit the same suite on disk but do NOT fire callbacks here. Those writes
  /// are caught later by the foreground pull (`willEnterForegroundNotification`)
  /// or the next rate-limited pull from `ListSyncRefreshService`. Today no
  /// extension target writes `library_sort:*` keys, so this is documentation —
  /// add a `UserDefaults.didChangeNotification` listener if that ever changes.
  private func addObserver(forKey key: String) {
    guard !registeredKeys.contains(key) else { return }
    registeredKeys.insert(key)
    defaults.addObserver(self, forKeyPath: key, options: [.new, .old], context: nil)
  }

  /// Snapshot of currently-stored values under `prefix`, normalized to
  /// string descriptions so the type-agnostic comparison in
  /// `pullFromServer` works across both `String` (sort) and `Bool`
  /// (display) value shapes.
  private func currentValues(forPrefix prefix: String) -> [String: String] {
    var result: [String: String] = [:]
    let domain = defaults.dictionaryRepresentation()
    for (key, value) in domain where key.hasPrefix(prefix) {
      result[key] = String(describing: value)
    }
    return result
  }

  /// Companion to `currentValues(forPrefix:)`: reads the currently-stored
  /// value for a single key in the same string-description form.
  /// Returns nil if no value is stored.
  private func currentValue(forKey key: String) -> String? {
    guard let value = defaults.object(forKey: key) else { return nil }
    return String(describing: value)
  }

  /// Applies the server snapshot to UserDefaults with the remote-update flag set.
  /// Returns the keys that were actually written (passed LWW check).
  ///
  /// Each tracked prefix has its own value-shape contract:
  /// - `library_sort:` → `{"sort": "<EffectiveSort.rawValue>"}` (String)
  /// - `library_display:` → `{"value": <Bool>}` (Bool)
  ///
  /// Entries with unknown prefixes or malformed payloads are skipped — a bad
  /// server response must not silently overwrite a good local pref.
  private func applyServerSnapshot(_ entries: [PreferencesSyncEntry]) -> [String] {
    lock.lock()
    isApplyingRemoteUpdate = true
    defer {
      isApplyingRemoteUpdate = false
      lock.unlock()
    }

    var applied: [String] = []
    for entry in entries {
      // LWW: if the key is dirty AND server is not newer than our local change, skip.
      if let localChangeAt = dirty[entry.key], entry.updatedAt <= localChangeAt {
        continue
      }

      guard let decoded = decodeServerValue(forKey: entry.key, value: entry.value) else {
        Self.logger.trace("PreferencesSyncService: skipping entry with unrecognized value for key \(entry.key)")
        continue
      }

      defaults.set(decoded, forKey: entry.key)
      applied.append(entry.key)

      // Server superseded any pending local write.
      if dirty.removeValue(forKey: entry.key) != nil {
        persistDirtyList()
      }
    }
    return applied
  }

  /// Resolves the server entry to the local-storage value, deferring to the
  /// schema that owns the key. Returns `nil` for malformed payloads or
  /// untracked prefixes.
  private func decodeServerValue(forKey key: String, value: [String: AnyDecodable]) -> Any? {
    schema(forKey: key)?.decode(value)
  }

  /// Builds the server-side `value` payload for a dirty key, deferring to
  /// the schema that owns the key. Returns `nil` for untracked prefixes —
  /// only tracked keys reach the dirty list, so this is defensive.
  private func encodeServerValue(forKey key: String) -> [String: Any]? {
    schema(forKey: key)?.encode(key, defaults)
  }

  /// Runs the schema's declared side effect after a remote-pulled value
  /// changes a tracked key. `@AppStorage` subscribers re-render on their
  /// own — this is for service-internal work that needs to follow the
  /// new value (e.g. re-ranking items when sort changes).
  private func dispatchSideEffect(forKey key: String) async {
    guard let schema = schema(forKey: key) else { return }
    switch schema.sideEffect {
    case .resort:
      await dispatchResort(forKey: key)
    case .none:
      break
    }
  }

  private func dispatchResort(forKey key: String) async {
    let location: SortLocation
    if key == Constants.UserDefaults.librarySortDefault {
      location = .libraryRoot
    } else if key.hasPrefix(Constants.UserDefaults.librarySortPrefix) {
      let uuid = String(key.dropFirst(Constants.UserDefaults.librarySortPrefix.count))
      guard Constants.isRealUuid(uuid) else { return }
      // Look up the relativePath for this folder uuid (best-effort; if folder
      // hasn't synced down yet, we just cache the pref and skip the re-sort).
      guard let relativePath = libraryService.getRelativePath(forUuid: uuid) else { return }
      // Route through `makeLocation` rather than constructing `.folder(...)`
      // directly, so bound-folder + placeholder-UUID gates apply uniformly
      // even on the server-driven path.
      location = libraryService.makeLocation(forRelativePath: relativePath)
    } else {
      return
    }

    guard
      case .automatic(let sort) = effectiveSort(forLocation: location)
    else { return }

    await MainActor.run {
      libraryService.sortContents(in: location, by: sort)
    }
  }

  // MARK: - Flush

  private func scheduleFlush() {
    // Take the lock here so callers (e.g. `observeValue`) can release the
    // lock before invoking us — keeps the publish-subscriber callback
    // out of any locked region.
    lock.lock()
    defer { lock.unlock() }
    flushTask?.cancel()
    flushTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: UInt64(Self.flushDebounce * Double(NSEC_PER_SEC)))
      guard !Task.isCancelled else { return }
      await self?.flush()
    }
  }

  private func flush() async {
    // Honor cancellation at each await boundary so a logout (which cancels
    // `flushTask`) can exit cleanly without sending a stale request or
    // mutating dirty state that's already been wiped.
    guard accountService.hasSyncEnabled(), !Task.isCancelled else { return }

    lock.lock()
    let snapshot = dirty
    lock.unlock()
    guard !snapshot.isEmpty, !Task.isCancelled else { return }

    var entries: [PreferenceEntry] = []
    for (key, _) in snapshot {
      guard let payload = encodeServerValue(forKey: key) else {
        // Unknown prefix shouldn't reach the dirty list (only tracked keys
        // get observed), but skip defensively rather than push garbage.
        continue
      }
      entries.append(PreferenceEntry(key: key, value: payload))
    }
    guard !entries.isEmpty else { return }

    do {
      let _: SuccessResponse = try await provider.request(.setPreferences(entries: entries))
    } catch {
      Self.logger.trace("PreferencesSyncService.flush failed: \(error.localizedDescription)")
      return
    }

    guard !Task.isCancelled else { return }

    lock.lock()
    for (key, ts) in snapshot {
      // Only clear keys whose timestamp matches what we shipped — the user
      // might have changed the same key again while the request was in flight.
      if dirty[key] == ts {
        dirty.removeValue(forKey: key)
      }
    }
    persistDirtyList()
    lock.unlock()
  }

  // MARK: - Dirty-list persistence

  /// Single formatter shared by encode + decode. Fractional seconds preserve
  /// sub-second precision so the round-trip matches the precision used by
  /// server timestamps (LWW comparisons rely on the two clocks being on the
  /// same scale).
  private static let dirtyListFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()

  private func persistDirtyList() {
    let encoded: [String: String] = dirty.mapValues { Self.dirtyListFormatter.string(from: $0) }
    if let data = try? JSONSerialization.data(withJSONObject: encoded) {
      defaults.set(data, forKey: Constants.UserDefaults.userPreferencesDirty)
    }
  }

  private func loadPersistedDirtyList() {
    guard
      let data = defaults.data(forKey: Constants.UserDefaults.userPreferencesDirty),
      let raw = try? JSONSerialization.jsonObject(with: data) as? [String: String]
    else { return }

    for (key, ts) in raw {
      if let date = Self.dirtyListFormatter.date(from: ts) {
        dirty[key] = date
      }
    }
  }
}

// MARK: - Preference schema

/// Service-internal action to run after a remote-pulled value writes to
/// `UserDefaults`. The view layer reacts to UserDefaults changes via
/// `@AppStorage` automatically; this enum names the work that the
/// **service** still has to do (e.g. re-rank items when sort changes).
///
/// Add a new case when a new preference family needs a new kind of work.
/// The `dispatchSideEffect` switch in `PreferencesSyncService` is the
/// single place that maps cases to implementations.
enum PreferenceSideEffect {
  /// Re-rank the affected library location's contents.
  case resort
  /// No service-side action — `@AppStorage` subscribers handle it.
  case none
}

/// Declarative description of a synced-preference family.
///
/// `PreferencesSyncService` holds an array of these and uses them as the
/// single source of truth for tracked prefixes, observed static keys, the
/// per-prefix codec used to talk to the server, and the side effect to run
/// after a remote update lands.
struct PreferenceSchema {
  /// All keys under this family share this prefix. KVO observation and
  /// the logout wipe both key off it.
  let prefix: String

  /// Keys observed eagerly at bootstrap. Per-instance keys (e.g. per-folder
  /// sort under `library_sort:<uuid>`) are registered lazily via
  /// `register(folderUuid:)` and are not listed here.
  let staticKeys: [String]

  /// Validates a server entry's `value` payload and returns the local-storage
  /// representation to write to `UserDefaults`, or `nil` if malformed.
  /// Receiving `nil` from this closure causes the entry to be skipped — a bad
  /// server response must never silently overwrite a good local pref.
  let decode: ([String: AnyDecodable]) -> Any?

  /// Reads the current local value for `key` from `defaults` and produces
  /// the dictionary the server expects under the entry's `value` field.
  let encode: (_ key: String, _ defaults: UserDefaults) -> [String: Any]

  /// Service-internal work to run after a remote update changes a key in
  /// this family. View-layer refresh is handled by `@AppStorage`, not here.
  let sideEffect: PreferenceSideEffect
}

// MARK: - Wire types

struct PreferencesSyncResponse: Decodable {
  let entries: [PreferencesSyncEntry]
}

struct PreferencesSyncEntry: Decodable {
  let key: String
  let value: [String: AnyDecodable]
  let updatedAt: Date

  enum CodingKeys: String, CodingKey {
    case key
    case value
    case updatedAt = "updated_at"
  }

  /// ISO8601 with fractional-seconds support. Server emits this format
  /// when the underlying timestamp has sub-second precision.
  private static let fractionalFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()

  /// ISO8601 without fractional-seconds. Server emits this format for
  /// timestamps with whole-second precision (the two options are mutually
  /// exclusive in `ISO8601DateFormatter`).
  private static let plainFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
  }()

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.key = try container.decode(String.self, forKey: .key)
    self.value = try container.decode([String: AnyDecodable].self, forKey: .value)
    let dateString = try container.decode(String.self, forKey: .updatedAt)
    if let date = Self.fractionalFormatter.date(from: dateString)
        ?? Self.plainFormatter.date(from: dateString) {
      self.updatedAt = date
    } else {
      // Throw rather than fall back to `Date.distantPast` — a silent fallback
      // would always make `entry.updatedAt <= localChangeAt`, so server values
      // for affected keys could never beat local LWW. Failing the whole pull
      // is loud and correct: the server is sending malformed timestamps and
      // a retry on next foreground is the right recovery.
      throw DecodingError.dataCorruptedError(
        forKey: .updatedAt,
        in: container,
        debugDescription: "Unrecognized ISO8601 timestamp: \(dateString)"
      )
    }
  }
}

private struct SuccessResponse: Decodable {
  let success: Bool
}

/// Type-erased decoder for arbitrary JSON values inside a pref's `value` object.
struct AnyDecodable: Decodable {
  let value: Any

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self.value = NSNull()
    } else if let bool = try? container.decode(Bool.self) {
      self.value = bool
    } else if let int = try? container.decode(Int.self) {
      self.value = int
    } else if let double = try? container.decode(Double.self) {
      self.value = double
    } else if let string = try? container.decode(String.self) {
      self.value = string
    } else if let array = try? container.decode([AnyDecodable].self) {
      self.value = array.map(\.value)
    } else if let dict = try? container.decode([String: AnyDecodable].self) {
      self.value = dict.mapValues(\.value)
    } else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Unsupported JSON value"
      )
    }
  }
}

