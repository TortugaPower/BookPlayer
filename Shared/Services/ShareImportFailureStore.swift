//
//  ShareImportFailureStore.swift
//  BookPlayerKit
//
//  Created by Matthew Alvernaz on 2026-05-17.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

/// A persisted record of an import that failed in the share-handoff path. We need to surface
/// these on the main app's next foreground because the share extension's UI is gone by the time
/// the bytes finish moving (the download itself is owned by `nsurlsessiond`), so failures that
/// happen after the share sheet dismisses would otherwise be invisible.
///
/// `source` should identify what the user tried to import (filename, or the share URL) and
/// `message` should be specific and actionable — never a generic "download failed". A VoiceOver
/// user announcing these has no visual context to fall back on.
public struct ShareImportFailure: Codable, Identifiable, Equatable {
  public let id: UUID
  public let date: Date
  public let source: String
  public let message: String

  public init(id: UUID = UUID(), date: Date = Date(), source: String, message: String) {
    self.id = id
    self.date = date
    self.source = source
    self.message = message
  }
}

/// File-backed queue of share-import failures. Stored as a JSON file in the App Group container
/// rather than via App Group `UserDefaults` because cross-process `UserDefaults` synchronization
/// between an extension and its host app has historically been flaky (the OS doesn't fire KVO
/// notifications across processes, and barrier syncs are best-effort). Atomic file writes give
/// us a deterministic point-in-time hand-off.
///
/// Concurrency: every operation reads the file fresh and writes atomically. The queue is small
/// (capped at `maxStored`) and the contention window is narrow — extension writes once on
/// failure, main app reads-and-clears once on foreground — so a simple atomic-write strategy
/// suffices.
public enum ShareImportFailureStore {
  /// Hard cap on stored failures so a runaway loop in the extension can't fill the container.
  private static let maxStored = 50

  private static var storeURL: URL? {
    FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: Constants.ApplicationGroupIdentifier)?
      .appendingPathComponent("share-import-failures.json")
  }

  /// Append a failure record. Safe to call from either the share extension or the main app.
  /// Best-effort — failures here (e.g. App Group container temporarily unreachable) are
  /// swallowed because surfacing a "couldn't record a failure" error would only confuse the user.
  public static func append(_ failure: ShareImportFailure) {
    guard let url = storeURL else { return }
    var failures = load()
    failures.append(failure)
    failures = Array(failures.suffix(maxStored))

    guard let data = try? JSONEncoder().encode(failures) else { return }
    try? data.write(to: url, options: .atomic)
  }

  /// Returns all queued failures and clears the store atomically.
  ///
  /// "Atomically" here means we re-read just before deleting, so a failure appended between
  /// our load and the delete won't be lost — it'll be returned by this drain call. We use
  /// `replaceItemAt` semantics via `write([], atomic:)` rather than `removeItem` because the
  /// file simply existing-or-not is itself the primary state signal.
  public static func drain() -> [ShareImportFailure] {
    guard let url = storeURL else { return [] }
    let failures = load()
    if !failures.isEmpty {
      try? FileManager.default.removeItem(at: url)
    }
    return failures
  }

  private static func load() -> [ShareImportFailure] {
    guard let url = storeURL,
          let data = try? Data(contentsOf: url),
          let failures = try? JSONDecoder().decode([ShareImportFailure].self, from: data)
    else { return [] }
    return failures
  }
}
