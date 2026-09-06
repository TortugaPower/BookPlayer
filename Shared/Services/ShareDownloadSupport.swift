//
//  ShareDownloadSupport.swift
//  BookPlayerKit
//
//  Created by Matthew Alvernaz on 2026-05-17.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

/// Helpers shared between the share extension's in-process download coordinator and the main
/// app's `BackgroundShareDownloadDelegate`. Both write into the App Group's shared folder and
/// have to defend against the same three failure shapes: filename traversal, collisions when
/// the same URL is shared twice, and servers that return HTML / JSON error bodies with a 200.
public enum ShareDownloadSupport {
  /// File extensions BookPlayer can usefully import. Mirrors the share extension's activation
  /// list — kept here because both download paths fall back to filename-extension matching
  /// when the server returns an ambiguous MIME type (e.g. `application/octet-stream`, or none).
  public static let supportedRemoteFileExtensions: Set<String> = [
    "mp3", "m4a", "m4b", "aac", "flac", "ogg", "opus", "wav", "wma",
    "aiff", "aif", "caf",
    "mp4", "m4v", "mov",
    "zip"
  ]

  /// MIME types we hard-reject because they are almost always Cloudflare interstitials, captive
  /// portals, login walls, or API error envelopes — never an audiobook file.
  private static let rejectedMIMEs: Set<String> = [
    "text/html", "text/plain", "application/json",
    "application/xml", "application/problem+json",
  ]

  /// MIME types we always accept without filename-extension validation.
  private static let acceptedMIMEs: Set<String> = [
    "application/zip", "application/x-zip-compressed",
    "application/x-mpegurl", "application/vnd.apple.mpegurl",
  ]

  /// MIME types that are ambiguous — sane servers send them for binary downloads, broken servers
  /// send them for everything. Accept only when the filename's extension is in our supported set.
  private static let ambiguousMIMEs: Set<String> = [
    "application/octet-stream", "binary/octet-stream",
    "application/download", "application/force-download",
  ]

  /// Strip path components, `..`, leading dots, and control characters from a server-suggested
  /// filename so it can't traverse out of the shared folder or otherwise corrupt the import
  /// destination.
  public static func sanitizedFilename(_ raw: String) -> String {
    // `lastPathComponent` collapses any `dir/file` shape down to `file`, and on Apple platforms
    // it also normalizes some control characters, but we still need to defend against `..`,
    // empty strings, and stray dots.
    var name = (raw as NSString).lastPathComponent
    while name.hasPrefix(".") { name.removeFirst() }
    name = name.replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "\\", with: "_")
      .replacingOccurrences(of: "\0", with: "_")
    if name.isEmpty || name == "." || name == ".." {
      return "shared-\(UUID().uuidString)"
    }
    // Cap length so a pathological server can't produce a name iOS will refuse to write.
    if name.count > 240 {
      let ext = (name as NSString).pathExtension
      let baseLimit = ext.isEmpty ? 240 : (240 - ext.count - 1)
      let base = (name as NSString).deletingPathExtension
      let trimmed = String(base.prefix(baseLimit))
      name = ext.isEmpty ? trimmed : "\(trimmed).\(ext)"
    }
    return name
  }

  /// Generate a collision-free destination filename by prefixing a short UUID. Used by both
  /// delegates so two simultaneous shares of the same URL don't overwrite each other.
  public static func uniqueDestinationName(for filename: String) -> String {
    let prefix = UUID().uuidString.prefix(8)
    return "\(prefix)-\(filename)"
  }

  /// Returns a localized rejection message when the downloaded bytes shouldn't be imported.
  /// `nil` means "accept this download". Layered: hard-reject known web/error MIMEs, accept
  /// known-good audio/archive MIMEs, fall back to filename-extension matching for ambiguous
  /// or missing MIME types.
  public static func rejectionReason(forMIME mime: String?, filename: String) -> String? {
    let pathExt = (filename as NSString).pathExtension.lowercased()
    let extensionMatches = !pathExt.isEmpty && supportedRemoteFileExtensions.contains(pathExt)

    if let mime, rejectedMIMEs.contains(mime) {
      return String(format: "share_import_failure_unsupported_type".localized, mime)
    }
    if let mime {
      if mime.hasPrefix("audio/") || mime.hasPrefix("video/") || acceptedMIMEs.contains(mime) {
        return nil
      }
      if ambiguousMIMEs.contains(mime) || mime.isEmpty {
        return extensionMatches
          ? nil
          : String(format: "share_import_failure_unsupported_extension".localized, filename)
      }
      // Unknown MIME: be generous if the filename extension is recognized, otherwise reject.
      return extensionMatches
        ? nil
        : String(format: "share_import_failure_unsupported_type".localized, mime)
    }
    // No MIME header at all — defer to filename extension.
    return extensionMatches
      ? nil
      : String(format: "share_import_failure_unsupported_extension".localized, filename)
  }
}
