//
//  ShareCancelStore.swift
//  BookPlayerKit
//
//  Created by Matthew Alvernaz on 2026-05-17.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

/// File-backed set of "canceled share IDs" stored in the App Group container.
///
/// The share extension lives for seconds — once the user taps Cancel, iOS is free to tear it
/// down before any in-flight `URLSessionDownloadTask.cancel()` propagates to `nsurlsessiond`.
/// Best-effort task cancellation alone isn't enough; the main app might still receive a
/// completion event for a download the user thought they aborted, and would happily move the
/// resulting file into the library.
///
/// `ShareCancelStore` plugs that gap: the share extension marks the `shareID` here just before
/// dismissing, and the host app's `BackgroundShareDownloadDelegate` checks the set when a
/// completion arrives. If the id is in the canceled set, the temp file gets removed and the
/// import doesn't happen.
///
/// Implementation notes mirror `ShareImportFailureStore`: a small JSON file in the App Group,
/// atomic writes, capped size to bound the worst case if cleanup ever fails.
public enum ShareCancelStore {
  /// Hard cap so a runaway loop can't fill the App Group container.
  private static let maxStored = 100

  private static var storeURL: URL? {
    FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: Constants.ApplicationGroupIdentifier)?
      .appendingPathComponent("share-canceled.json")
  }

  /// Mark one or more share IDs as canceled. Idempotent — adding an id that's already in the
  /// set is a no-op. Returns silently on App Group / encoding failures because surfacing them
  /// would be worse UX than the marginal risk of a "ghost" download landing.
  public static func markCanceled(_ ids: [String]) {
    guard let url = storeURL, !ids.isEmpty else { return }
    var canceled = load()
    canceled.formUnion(ids)
    // Cap by trimming the oldest insertion order. Because `Set` doesn't preserve insertion
    // order, we just trim arbitrarily — the cap exists as a hygiene guard, not a precise FIFO.
    if canceled.count > maxStored {
      canceled = Set(canceled.prefix(maxStored))
    }
    guard let data = try? JSONEncoder().encode(canceled) else { return }
    try? data.write(to: url, options: .atomic)
  }

  /// Check whether a given share id was canceled. Cheap — reads the file each call rather than
  /// caching, so two near-simultaneous completions from different shares don't race a stale cache.
  public static func isCanceled(_ id: String) -> Bool {
    return load().contains(id)
  }

  /// Remove an id from the canceled set, e.g. after we've successfully suppressed its
  /// completion handler. Keeps the file from growing unbounded across many cancel/share cycles.
  public static func clear(_ id: String) {
    guard let url = storeURL else { return }
    var canceled = load()
    guard canceled.contains(id) else { return }
    canceled.remove(id)
    if canceled.isEmpty {
      try? FileManager.default.removeItem(at: url)
      return
    }
    guard let data = try? JSONEncoder().encode(canceled) else { return }
    try? data.write(to: url, options: .atomic)
  }

  private static func load() -> Set<String> {
    guard let url = storeURL,
          let data = try? Data(contentsOf: url),
          let set = try? JSONDecoder().decode(Set<String>.self, from: data)
    else { return [] }
    return set
  }
}
