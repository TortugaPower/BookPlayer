//
//  SharedWidgetStore.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/6/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation
import WidgetKit

/// Owns the read-modify-write of the "Last Played" widget snapshot stored in the
/// App Group shared `UserDefaults`. Centralizing it here keeps the write path
/// (on playback) and the prune path (on deletion) symmetric: same key, same coder,
/// same cap. Both paths reload the widget timeline after mutating the snapshot.
///
/// The write path runs on the main thread (playback) while the prune path can run on
/// a background Core Data context (remote/sync delete), so every snapshot mutation is
/// serialized on `mutationQueue` to keep each `load`→modify→`persist` atomic — without
/// it, a concurrent prune and store could race and re-introduce a just-deleted item.
public final class SharedWidgetStore {
  private init() {}

  private static let key = Constants.UserDefaults.sharedWidgetLastPlayedItems
  /// Cap on retained recent items; matches the previous `storeWidgetItem` behavior.
  private static let maxItems = 10
  /// Serializes all snapshot read-modify-write so concurrent `store`/`removeItems`
  /// calls from different threads can't clobber each other's writes.
  private static let mutationQueue = DispatchQueue(label: "com.bookplayer.sharedWidgetStore")
  /// Coalescing window for Last Played widget reloads. Several mutations can land in
  /// quick succession (deleting books one-by-one, or a folder delete that prunes
  /// multiple entries), so we debounce into a single reload to stay within iOS's
  /// widget-reload budget. Mirrors `WidgetReloadService.scheduleWidgetReload`.
  private static let reloadDebounce: DispatchTimeInterval = .seconds(5)
  private static var pendingReload: DispatchWorkItem?

  /// Prepend `item` to the snapshot, dedupe by `relativePath`, cap at 10, persist, reload.
  /// Runs asynchronously on `mutationQueue` so the playback path never blocks.
  public static func store(_ item: PlayableItem) {
    mutationQueue.async {
      var items = [item]
      items.append(contentsOf: load().filter { $0.relativePath != item.relativePath })
      persist(Array(items.prefix(maxItems)))
      reload()
    }
  }

  /// Remove any snapshot entry that was deleted: an entry is pruned when its
  /// `relativePath` exactly matches one of `relativePaths`, or is a descendant of it
  /// (prefix `path + "/"`). The descendant rule covers folder deletions (deep delete's
  /// children and shallow delete's moved children both share the folder prefix), as
  /// well as moved/renamed items whose old paths are now stale.
  /// Runs asynchronously on `mutationQueue`; persists and reloads only when something
  /// actually changed, so callers (including the background sync-delete path) never block.
  public static func removeItems(matching relativePaths: [String]) {
    guard !relativePaths.isEmpty else { return }

    mutationQueue.async {
      let current = load()
      guard !current.isEmpty else { return }

      /// Precompute once: O(1) exact-match lookups, and the descendant prefixes
      /// allocated a single time instead of once per snapshot entry.
      let deletedPaths = Set(relativePaths)
      let descendantPrefixes = relativePaths.map { $0 + "/" }

      let pruned = current.filter { entry in
        if deletedPaths.contains(entry.relativePath) { return false }
        return !descendantPrefixes.contains { entry.relativePath.hasPrefix($0) }
      }

      guard pruned.count != current.count else { return }

      persist(pruned)
      reload()
    }
  }

  /// Must be called on `mutationQueue`.
  private static func load() -> [PlayableItem] {
    guard
      let data = UserDefaults.sharedDefaults.data(forKey: key),
      let items = try? JSONDecoder().decode([PlayableItem].self, from: data)
    else { return [] }

    return items
  }

  /// Must be called on `mutationQueue`.
  private static func persist(_ items: [PlayableItem]) {
    guard let data = try? JSONEncoder().encode(items) else { return }

    UserDefaults.sharedDefaults.set(data, forKey: key)
  }

  /// Debounced reload of the Last Played widget. `SharedWidgetStore` is the only
  /// reloader of this widget kind, so a self-contained debouncer fully coalesces its
  /// reloads. All bookkeeping runs on the main queue, so the shared work item is safe
  /// to touch from the background sync-delete path.
  private static func reload() {
    DispatchQueue.main.async {
      pendingReload?.cancel()

      let workItem = DispatchWorkItem {
        pendingReload = nil
        WidgetCenter.shared.reloadTimelines(ofKind: Constants.Widgets.lastPlayedWidget.rawValue)
      }

      pendingReload = workItem
      DispatchQueue.main.asyncAfter(deadline: .now() + reloadDebounce, execute: workItem)
    }
  }

  /// Test support: blocks until all queued mutations have completed. `internal`, so it is
  /// only reachable via `@testable import`, never from app/widget code.
  static func waitForPendingMutations() {
    mutationQueue.sync {}
  }
}
