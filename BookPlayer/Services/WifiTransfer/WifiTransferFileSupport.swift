//
//  WifiTransferFileSupport.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

enum WifiTransferFileSupport {
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

  /// Sanitize a client-supplied name so it cannot escape the staging directory.
  static func sanitizedFilename(from raw: String) -> String? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    let base = (trimmed as NSString).lastPathComponent
    guard base != ".", base != "..", !base.isEmpty else { return nil }
    guard isAllowedFilename(base) else { return nil }
    return base
  }

  /// Collision-safe URL under `directory` for `filename`.
  static func uniqueFileURL(filename: String, in directory: URL) -> URL {
    var candidate = directory.appendingPathComponent(filename)
    guard FileManager.default.fileExists(atPath: candidate.path) else {
      return candidate
    }
    let name = (filename as NSString).deletingPathExtension
    let ext = (filename as NSString).pathExtension
    var index = 1
    repeat {
      let suffix = ext.isEmpty ? "\(name) (\(index))" : "\(name) (\(index)).\(ext)"
      candidate = directory.appendingPathComponent(suffix)
      index += 1
    } while FileManager.default.fileExists(atPath: candidate.path)
    return candidate
  }
}
