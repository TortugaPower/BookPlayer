//
//  PreferencesSyncService.swift
//  BookPlayer
//
//  Watches App-Group UserDefaults via per-key KVO, batches local changes
//  to the backend, and applies remote changes in. Source of truth is
//  UserDefaults itself; this service is a passive observer + sync coordinator.
//
//  See plan: /Users/pro.gianni.carlo/.claude/plans/can-you-spawn-a-staged-marble.md
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

  // MARK: - Dependencies

  private let accountService: AccountServiceProtocol
  private let libraryService: LibraryServiceProtocol
  private let defaults: UserDefaults
  private let provider: NetworkProvider<PreferencesAPI>

  // MARK: - State

  /// Tracked-key prefixes. Currently just sticky-sort keys.
  private let trackedPrefixes: [String] = [Constants.UserDefaults.librarySortPrefix]

  /// Static (non-prefixed) tracked keys.
  private var staticTrackedKeys: [String] {
    [Constants.UserDefaults.librarySortDefault]
  }

  /// Currently registered KVO key paths.
  private var registeredKeys: Set<String> = []

  /// Keys awaiting server flush, with the timestamp of the local change.
  /// Persisted to `userPreferences.dirty` synchronously on every mutation.
  private var dirty: [String: Date] = [:]

  /// Last successful pull timestamp; gates `pullFromServer(force: false)`.
  private var lastSuccessfulPull: Date?
  private let pullCooldown: TimeInterval = 30

  /// Set during `applyServerSnapshot` to suppress KVO echoes.
  private var isApplyingRemoteUpdate = false

  /// Pending debounced flush.
  private var flushTask: Task<Void, Never>?
  private let flushDebounce: TimeInterval = 3

  /// Concurrency lock guarding `dirty`, `registeredKeys`, `flushTask`,
  /// `lastSuccessfulPull`, `isApplyingRemoteUpdate`. KVO callbacks fire
  /// on the calling thread; foreground/login signals come on main; pull
  /// runs in a Task. Access is serialized via this queue.
  private let lock = NSRecursiveLock()

  /// Account-state and lifecycle observers (logout, accountUpdate, foreground).
  private var notificationObservers: [NSObjectProtocol] = []

  // MARK: - Init

  public init(
    accountService: AccountServiceProtocol,
    libraryService: LibraryServiceProtocol,
    defaults: UserDefaults = UserDefaults(suiteName: Constants.ApplicationGroupIdentifier) ?? .standard,
    client: NetworkClientProtocol = NetworkClient()
  ) {
    self.accountService = accountService
    self.libraryService = libraryService
    self.defaults = defaults
    self.provider = NetworkProvider<PreferencesAPI>(client: client)
    super.init()
  }

  deinit {
    for key in registeredKeys {
      defaults.removeObserver(self, forKeyPath: key)
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
      // `force: false` here so co-firing with the foreground observer dedupes
      // via the 30s rate limit. If `lastSuccessfulPull` is nil (first time
      // sync becomes enabled), the rate limit doesn't trigger and the pull happens.
      // Also flush any locally-accumulated dirty entries (e.g. free user upgrades to Pro).
      Task { [weak self] in
        await self?.pullFromServer(force: false)
        await self?.flush()
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
    if !force, let last = lastSuccessfulPull, Date().timeIntervalSince(last) < pullCooldown {
      lock.unlock()
      return
    }
    lock.unlock()

    let prefix = Constants.UserDefaults.librarySortPrefix
    let response: PreferencesSyncResponse
    do {
      response = try await provider.request(.getPreferences(prefix: prefix))
    } catch {
      Self.logger.trace("PreferencesSyncService.pullFromServer failed: \(error.localizedDescription)")
      return
    }

    let beforeSnapshot = currentValues(forPrefix: prefix)
    let appliedKeys = applyServerSnapshot(response.entries)

    lock.lock()
    lastSuccessfulPull = Date()
    lock.unlock()

    // Walk applied keys and re-sort affected locations.
    for key in appliedKeys {
      let oldValue = beforeSnapshot[key]
      let newValue = defaults.string(forKey: key)
      if oldValue == newValue { continue }
      await dispatchResort(forKey: key)
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
    lock.lock()
    defer { lock.unlock() }

    guard !isApplyingRemoteUpdate else { return }
    guard let key = keyPath else { return }

    let oldValue = (change?[.oldKey] as? String) ?? ""
    let newValue = (change?[.newKey] as? String) ?? ""
    guard oldValue != newValue else { return }

    dirty[key] = Date()
    persistDirtyList()
    preferencesChanged.send(key)
    scheduleFlush()
  }

  // MARK: - Private

  private func addObserver(forKey key: String) {
    guard !registeredKeys.contains(key) else { return }
    registeredKeys.insert(key)
    defaults.addObserver(self, forKeyPath: key, options: [.new, .old], context: nil)
  }

  private func currentValues(forPrefix prefix: String) -> [String: String] {
    var result: [String: String] = [:]
    let domain = defaults.dictionaryRepresentation()
    for (key, value) in domain where key.hasPrefix(prefix) {
      if let str = value as? String {
        result[key] = str
      }
    }
    return result
  }

  /// Applies the server snapshot to UserDefaults with the remote-update flag set.
  /// Returns the keys that were actually written (passed LWW check).
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

      let stringValue = (entry.value["sort"]?.value as? String) ?? ""
      defaults.set(stringValue, forKey: entry.key)
      applied.append(entry.key)

      // Server superseded any pending local write.
      if dirty.removeValue(forKey: entry.key) != nil {
        persistDirtyList()
      }
    }
    return applied
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
      location = .folder(LibraryItemRef(relativePath: relativePath, uuid: uuid))
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
    flushTask?.cancel()
    flushTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: UInt64((self?.flushDebounce ?? 3) * 1_000_000_000))
      guard !Task.isCancelled else { return }
      await self?.flush()
    }
  }

  private func flush() async {
    guard accountService.hasSyncEnabled() else { return }

    lock.lock()
    let snapshot = dirty
    lock.unlock()
    guard !snapshot.isEmpty else { return }

    var entries: [PreferenceEntry] = []
    for (key, _) in snapshot {
      let raw = defaults.string(forKey: key) ?? ""
      entries.append(PreferenceEntry(key: key, value: ["sort": raw]))
    }

    do {
      let _: SuccessResponse = try await provider.request(.setPreferences(entries: entries))
    } catch {
      Self.logger.trace("PreferencesSyncService.flush failed: \(error.localizedDescription)")
      return
    }

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

  private func persistDirtyList() {
    let formatter = ISO8601DateFormatter()
    let encoded: [String: String] = dirty.mapValues { formatter.string(from: $0) }
    if let data = try? JSONSerialization.data(withJSONObject: encoded) {
      defaults.set(data, forKey: Constants.UserDefaults.userPreferencesDirty)
    }
  }

  private func loadPersistedDirtyList() {
    guard
      let data = defaults.data(forKey: Constants.UserDefaults.userPreferencesDirty),
      let raw = try? JSONSerialization.jsonObject(with: data) as? [String: String]
    else { return }

    let formatter = ISO8601DateFormatter()
    for (key, ts) in raw {
      if let date = formatter.date(from: ts) {
        dirty[key] = date
      }
    }
  }
}

// MARK: - Wire types

private struct PreferencesSyncResponse: Decodable {
  let entries: [PreferencesSyncEntry]
}

private struct PreferencesSyncEntry: Decodable {
  let key: String
  let value: [String: AnyDecodable]
  let updatedAt: Date

  enum CodingKeys: String, CodingKey {
    case key
    case value
    case updatedAt = "updated_at"
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.key = try container.decode(String.self, forKey: .key)
    self.value = try container.decode([String: AnyDecodable].self, forKey: .value)
    let dateString = try container.decode(String.self, forKey: .updatedAt)
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: dateString) {
      self.updatedAt = date
    } else {
      let plainFormatter = ISO8601DateFormatter()
      plainFormatter.formatOptions = [.withInternetDateTime]
      self.updatedAt = plainFormatter.date(from: dateString) ?? Date.distantPast
    }
  }
}

private struct SuccessResponse: Decodable {
  let success: Bool
}

/// Type-erased decoder for arbitrary JSON values inside a pref's `value` object.
private struct AnyDecodable: Decodable {
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

