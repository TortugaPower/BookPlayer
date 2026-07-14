//
//  ErrorReporter.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 13/7/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

/// Bridge for non-fatal error reporting from shared code (BookPlayerKit /
/// BookPlayerWatchKit) to the crash reporting SDK, which only the main app
/// target links. The app installs a handler at launch; targets that never
/// install one (e.g. the watch app) make reporting a no-op.
public enum ErrorReporter {
  /// Installed once at app launch; must be safe to call from any thread.
  public static var handler: ((_ title: String, _ error: Error, _ tags: [String: String]) -> Void)?

  /// Report a non-fatal error.
  /// - Parameters:
  ///   - title: Stable grouping key — events with the same title collapse into
  ///     one issue. Parameterize it only with values worth splitting issues
  ///     over (endpoint, field), never with user content.
  ///   - error: The underlying error, sent as event detail.
  ///   - tags: Extra searchable metadata.
  public static func report(title: String, error: Error, tags: [String: String] = [:]) {
    handler?(title, error, tags)
  }
}
