//
//  WifiTransferFileSupport.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

enum WifiTransferFileSupport {
  /// Staging area outside Documents so DirectoryWatcher does not import files mid-upload.
  static var stagingRootURL: URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("BookPlayerWifiTransfer", isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  /// Extensions accepted by the Wi‑Fi transfer page (aligned with import / document types).
  static let allowedExtensions: Set<String> = [
    "mp3", "m4b", "m4a", "m4v", "aax", "aaxc",
    "wav", "flac", "opus", "ogg", "oga",
    "mp4", "mov", "avi",
    "zip", "lpf",
  ]

  static func isAllowedFilename(_ filename: String) -> Bool {
    let ext = (filename as NSString).pathExtension.lowercased()
    guard !ext.isEmpty else { return false }
    return allowedExtensions.contains(ext)
  }

  /// Sanitize a client-supplied basename so it cannot escape the staging directory.
  static func sanitizedFilename(from raw: String) -> String? {
    sanitizedRelativePath(from: raw).flatMap { path in
      path.contains("/") ? nil : path
    }
  }

  /// Sanitize a relative path (`Book/Disc 1/01.mp3`). Rejects `..`, absolute paths, empty segments.
  static func sanitizedRelativePath(from raw: String) -> String? {
    var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    trimmed = trimmed.replacingOccurrences(of: "\\", with: "/")
    while trimmed.hasPrefix("./") {
      trimmed = String(trimmed.dropFirst(2))
    }
    if trimmed.hasPrefix("/") { return nil }
    if trimmed.contains("://") { return nil }

    let segments = trimmed.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
    guard !segments.isEmpty else { return nil }

    var clean: [String] = []
    for segment in segments {
      guard !segment.isEmpty else { return nil }
      guard segment != ".", segment != ".." else { return nil }
      guard !segment.contains("\0") else { return nil }
      clean.append(segment)
    }
    guard let filename = clean.last, isAllowedFilename(filename) else { return nil }
    return clean.joined(separator: "/")
  }

  /// Single folder name for `POST /import?root=`.
  static func sanitizedRootFolder(from raw: String) -> String? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: "\\", with: "/")
    guard !trimmed.isEmpty else { return nil }
    let base = (trimmed as NSString).lastPathComponent
    guard base != ".", base != "..", !base.isEmpty else { return nil }
    guard !base.contains("/") else { return nil }
    // Folder names don't need an audio extension
    guard !base.hasPrefix(".") else { return nil }
    return base
  }

  /// Whether the relative path is a top-level file (import immediately) vs nested under a folder.
  static func isLooseFilePath(_ relativePath: String) -> Bool {
    !relativePath.contains("/")
  }

  /// Collision-safe URL under `directory` for a relative path (creates parent folders).
  static func uniqueFileURL(relativePath: String, in directory: URL) -> URL? {
    guard let relativePath = sanitizedRelativePath(from: relativePath) else { return nil }
    let destination = directory.appendingPathComponent(relativePath)
    let parent = destination.deletingLastPathComponent()
    do {
      try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
    } catch {
      return nil
    }

    guard FileManager.default.fileExists(atPath: destination.path) else {
      return destination
    }

    let filename = destination.lastPathComponent
    let name = (filename as NSString).deletingPathExtension
    let ext = (filename as NSString).pathExtension
    var index = 1
    var candidate: URL
    repeat {
      let suffix = ext.isEmpty ? "\(name) (\(index))" : "\(name) (\(index)).\(ext)"
      candidate = parent.appendingPathComponent(suffix)
      index += 1
    } while FileManager.default.fileExists(atPath: candidate.path)
    return candidate
  }

  /// Collision-safe URL under `directory` for a basename only.
  static func uniqueFileURL(filename: String, in directory: URL) -> URL {
    uniqueFileURL(relativePath: filename, in: directory)
      ?? directory.appendingPathComponent(filename)
  }
}
