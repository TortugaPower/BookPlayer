//
//  IntegrationConnectionStore.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 25/7/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

/// Keychain-backed storage for a single integration's saved connections.
///
/// Owns **persistence only**: loading, saving, de-duplication and active-selection bookkeeping.
/// Integration-specific side effects — rebuilding a `JellyfinClient`, firing AudiobookShelf's
/// `/logout` to revoke a token server-side — deliberately stay in the owning service, which reacts
/// to the values these methods return. That split is what keeps this type free of network and
/// UIKit, and therefore unit-testable with `KeychainServiceMock` plus a throwaway `UserDefaults`.
@MainActor
@Observable
final class IntegrationConnectionStore<Payload: IntegrationConnectionPayload>: BPLogger {
  /// Outcome of an `upsert`, so the caller can react to what was displaced.
  struct UpsertResult {
    let saved: Payload
    /// The record this replaced, when re-authenticating an account that was already saved.
    /// `nil` for a brand-new connection.
    let replaced: Payload?
  }

  private(set) var connections: [Payload] = []

  /// Stored (not a computed `UserDefaults` passthrough) so `@Observable` can track it: a purely
  /// computed property has no stored member for observation to register against, so activating a
  /// connection would not refresh a view reading `active`. Always mutate it through
  /// `setActiveConnectionID(_:)`, which keeps `UserDefaults` in step — assigning directly would
  /// update the UI but lose the choice on next launch.
  private(set) var activeConnectionID: String?

  /// The active connection, falling back to the first saved one when the stored id is missing or
  /// stale. Matches the behaviour both integrations shipped with.
  var active: Payload? {
    if let activeConnectionID,
      let match = connections.first(where: { $0.id == activeConnectionID })
    {
      return match
    }
    return connections.first
  }

  // These are written by the `nonisolated init` below, and a MainActor-isolated stored property can't
  // be assigned from a nonisolated context — a warning today, an error under the Swift 6 language mode.
  // `String` and `KeychainServiceProtocol` are `Sendable`, so plain `nonisolated` suffices and the
  // compiler checks them. `KeychainKeys` and `UserDefaults` are not, so they need the explicit escape
  // hatch: safe here because both are written exactly once during init and only ever read afterwards.
  private nonisolated(unsafe) let keychainKey: KeychainKeys
  private nonisolated let activeIDDefaultsKey: String
  private nonisolated let keychain: KeychainServiceProtocol
  private nonisolated(unsafe) let defaults: UserDefaults

  /// `nonisolated` because the owning services are constructed as `@Entry` environment
  /// placeholders outside any actor. Only plain stored values are set here; the persisted active id
  /// is seeded in `reload()` instead, so no isolated property is touched during init.
  nonisolated init(
    keychainKey: KeychainKeys,
    activeIDDefaultsKey: String,
    keychain: KeychainServiceProtocol,
    defaults: UserDefaults = .standard
  ) {
    self.keychainKey = keychainKey
    self.activeIDDefaultsKey = activeIDDefaultsKey
    self.keychain = keychain
    self.defaults = defaults
  }

  /// Single funnel for changing the active connection, so the observable value and the persisted
  /// one can't drift apart.
  private func setActiveConnectionID(_ id: String?) {
    activeConnectionID = id
    if let id {
      defaults.set(id, forKey: activeIDDefaultsKey)
    } else {
      defaults.removeObject(forKey: activeIDDefaultsKey)
    }
  }

  // MARK: - Loading

  /// Loads saved connections, dropping unusable records and migrating the pre-multi-server
  /// single-object format. Also normalizes `activeConnectionID` so it always points at a record
  /// that exists (or is `nil` when there are none).
  func reload() {
    // Seed the persisted choice *before* normalizing. Skipping this would leave the id nil and let
    // normalization silently reset the user's active server to the first one on every launch.
    activeConnectionID = defaults.string(forKey: activeIDDefaultsKey)

    if let stored: [Payload] = try? keychain.get(keychainKey) {
      connections = stored.filter { $0.isUsable }
      // Persist immediately if we dropped anything, so the bad records don't linger.
      if connections.count != stored.count {
        save()
      }
    } else if let single: Payload = try? keychain.get(keychainKey), single.isUsable {
      // Migrate from the single-connection format written before multi-server support.
      connections = [single]
      save()
    } else {
      Self.logger.warning("failed to load connection data from keychain")
      return
    }

    normalizeActiveID()
  }

  private func normalizeActiveID() {
    if connections.isEmpty {
      setActiveConnectionID(nil)
    } else if let current = activeConnectionID {
      if !connections.contains(where: { $0.id == current }) {
        setActiveConnectionID(connections.first?.id)
      }
    } else {
      setActiveConnectionID(connections.first?.id)
    }
  }

  // MARK: - Mutation

  /// Inserts or replaces the connection for one account and makes it active.
  ///
  /// `build` receives the record already saved for this `(url, userID)` pair, if any, so callers can
  /// carry forward the values that must survive a re-authentication — the connection `id` (kept so
  /// outbound references stay valid) and `selectedLibraryId` (kept so the user lands back in the
  /// same library). Construction stays with the caller because only the concrete type knows which
  /// stored property holds its token.
  /// `replacingID` names the connection a re-authentication started from. When the sign-in lands on
  /// the same account at a *different* URL — a server that moved host, which self-hosters do
  /// constantly — the account match finds nothing, and without this the old row would survive as an
  /// expired orphan next to the new one. The replaced row only matches when its `userID` agrees:
  /// signing into a different account is genuinely a new connection, not a move.
  @discardableResult
  func upsert(
    url: URL,
    userID: String,
    replacingID: String? = nil,
    build: (Payload?) -> Payload
  ) -> UpsertResult {
    let replaced = connections.first { $0.isSameAccount(as: url, userID: userID) }
      ?? connections.first { $0.id == replacingID && $0.userID == userID }
    let saved = build(replaced)

    connections.removeAll { $0.isSameAccount(as: url, userID: userID) || $0.id == replaced?.id }
    connections.append(saved)
    setActiveConnectionID(saved.id)
    save()

    return UpsertResult(saved: saved, replaced: replaced)
  }

  /// Makes `id` active. Returns `false` when no such connection exists, in which case nothing
  /// changed and the caller should not rebuild any client.
  @discardableResult
  func setActive(id: String) -> Bool {
    guard connections.contains(where: { $0.id == id }) else { return false }
    setActiveConnectionID(id)
    return true
  }

  /// Removes a connection and returns the record that was dropped, so the caller can run any
  /// server-side teardown against it. Clears the Keychain entry entirely once the last one goes.
  @discardableResult
  func remove(id: String) -> Payload? {
    guard let removed = connections.first(where: { $0.id == id }) else { return nil }

    connections.removeAll { $0.id == id }

    if activeConnectionID == id {
      setActiveConnectionID(connections.first?.id)
    }

    if connections.isEmpty {
      do {
        try keychain.remove(keychainKey)
      } catch {
        Self.logger.warning("failed to remove connection data from keychain: \(error)")
      }
    } else {
      save()
    }

    return removed
  }

  /// Persists `headers` against one connection regardless of which is active. Returns `false` when
  /// the id is unknown, so callers can skip updating a live header injector.
  @discardableResult
  func updateCustomHeaders(id: String, _ headers: [String: String]) -> Bool {
    guard let index = connections.firstIndex(where: { $0.id == id }) else { return false }
    connections[index].customHeaders = headers
    save()
    return true
  }

  /// Persists the selected library against one connection.
  @discardableResult
  func setSelectedLibrary(id: String, libraryId: String?) -> Bool {
    guard let index = connections.firstIndex(where: { $0.id == id }) else { return false }
    connections[index].selectedLibraryId = libraryId
    save()
    return true
  }

  private func save() {
    do {
      try keychain.set(connections, key: keychainKey)
    } catch {
      // In-memory state already moved on; without this a token that never
      // persisted (and vanishes on next launch) would be undiagnosable
      Self.logger.warning("failed to persist connection data to keychain: \(error)")
    }
  }
}
