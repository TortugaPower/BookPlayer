//
//  TransferServerSupport.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation
import Security

enum TransferServerSupport {
  static let stagingFolderName = "BookPlayerTransferServer"

  /// Hard cap per uploaded file (prevents a LAN peer from filling the device).
  static let maxUploadBytes = 8 * 1024 * 1024 * 1024

  static let defaultPort: UInt16 = 8080
  static let minimumPort: UInt16 = 1024
  static let maximumPort: UInt16 = 65_535

  /// Header browsers send when optional PIN protection is enabled.
  static let pinHeaderName = "X-BookPlayer-Transfer-Pin"

  enum Preferences {
    static let portKey = "transfer_server_port"
    static let requirePinKey = "transfer_server_require_pin"
    static let pinKey = "transfer_server_pin"

    static var port: UInt16 {
      get {
        let raw = UserDefaults.standard.object(forKey: portKey) as? Int
        return clampedPort(UInt16(clamping: raw ?? Int(defaultPort)))
      }
      set {
        UserDefaults.standard.set(Int(clampedPort(newValue)), forKey: portKey)
      }
    }

    static var requirePin: Bool {
      get { UserDefaults.standard.bool(forKey: requirePinKey) }
      set { UserDefaults.standard.set(newValue, forKey: requirePinKey) }
    }

    /// Stored PIN when require-pin is on; `nil` otherwise.
    static var pin: String? {
      get {
        guard requirePin else { return nil }
        if let existing = UserDefaults.standard.string(forKey: pinKey),
          isPinFormat(existing)
        {
          return existing
        }
        let created = makePin()
        UserDefaults.standard.set(created, forKey: pinKey)
        return created
      }
      set {
        if let newValue, isPinFormat(newValue) {
          UserDefaults.standard.set(newValue, forKey: pinKey)
        } else {
          UserDefaults.standard.removeObject(forKey: pinKey)
        }
      }
    }

    @discardableResult
    static func regeneratePin() -> String {
      let created = makePin()
      UserDefaults.standard.set(created, forKey: pinKey)
      return created
    }
  }

  static func clampedPort(_ port: UInt16) -> UInt16 {
    min(max(port, minimumPort), maximumPort)
  }

  /// Four-digit PIN shown on the phone and typed on the web page.
  static func makePin() -> String {
    var bytes = [UInt8](repeating: 0, count: 2)
    _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
    let value = (UInt16(bytes[0]) << 8 | UInt16(bytes[1])) % 10_000
    return String(format: "%04d", value)
  }

  static func isPinFormat(_ pin: String) -> Bool {
    pin.count == 4 && pin.unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) }
  }

  /// Staging area outside Documents so DirectoryWatcher does not import files mid-upload.
  static var stagingRootURL: URL {
    let url = stagingRootURLIfPresent
      ?? FileManager.default.temporaryDirectory
        .appendingPathComponent(stagingFolderName, isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  /// Existing staging directory, or `nil` if nothing was left behind.
  static var stagingRootURLIfPresent: URL? {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(stagingFolderName, isDirectory: true)
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
      isDirectory.boolValue
    else {
      return nil
    }
    return url
  }

  /// Removes leftover Transfer server staging (crash / force-quit / aborted upload).
  /// Safe to call at launch and whenever the transfer server stops.
  @discardableResult
  static func clearStagingDirectory() -> Bool {
    guard let url = stagingRootURLIfPresent else { return false }
    do {
      try FileManager.default.removeItem(at: url)
      return true
    } catch {
      // Best-effort: retry by emptying contents if the root could not be removed.
      if let children = try? FileManager.default.contentsOfDirectory(
        at: url,
        includingPropertiesForKeys: nil
      ) {
        for child in children {
          try? FileManager.default.removeItem(at: child)
        }
      }
      try? FileManager.default.removeItem(at: url)
      return !FileManager.default.fileExists(atPath: url.path)
    }
  }

  /// Extensions accepted by the Transfer server page (aligned with import / document types).
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
