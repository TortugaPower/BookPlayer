//
//  MediaServerStreams.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

/// One audio file of a media-server item, as its server lists it when asked.
///
/// AudiobookShelf serves raw audio only per file: its item download is a zip for any book stored
/// in a folder, and a file's id is its inode, which changes whenever the file is replaced. So
/// files are looked up when a book is about to play or download, and never stored.
public struct ExternalStreamFile: Codable, Equatable, Hashable, Sendable {
  /// Relative to the saved server URL: `api/items/{id}/file/{ino}`.
  public let path: String
  /// The file's path inside the item's folder (`Disc 1/01.mp3`), else its file name. Unique
  /// within the item, so a volume's books are named after it.
  public let name: String
  public let duration: TimeInterval

  public init(path: String, name: String, duration: TimeInterval) {
    self.path = path
    self.name = name
    self.duration = duration
  }

  /// The file's URL on the server saved at `serverURL`, which may carry a reverse-proxy subpath.
  public func url(on serverURL: URL) -> URL {
    path.split(separator: "/").reduce(serverURL) { $0.appendingPathComponent(String($1)) }
  }
}

/// The names a stream import stores items under. Shared with the Android app
/// (`VirtualImportManager.importFileName` / `volumeChildFileNames`, `FilenameUtils.sanitizeFilename`)
/// so both apps name the same server item the same way.
public enum MediaServerFileNames {
  /// `name` made safe as one path component: separators and characters other systems reject
  /// become `_`, runs of `_` collapse, and leading or trailing `_` and `.` go.
  public static func sanitize(_ name: String) -> String {
    var sanitized = name.replacingOccurrences(of: #"[<>:"/\\|?*]"#, with: "_", options: .regularExpression)
    sanitized = sanitized.replacingOccurrences(of: "__+", with: "_", options: .regularExpression)
    sanitized = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "_."))

    return sanitized.isEmpty ? "untitled_file" : sanitized
  }

  /// The file name a single streamed book is stored under: its title and the REAL extension the
  /// server reported (with or without its leading dot).
  public static func importFileName(title: String, fileExtension: String) -> String {
    let fileExtension = fileExtension.hasPrefix(".") ? String(fileExtension.dropFirst()) : fileExtension

    return sanitize("\(title).\(fileExtension)")
  }

  /// The names a streamed volume's books are stored under, one per file in the server's order:
  /// each file's path inside the item's folder, flattened (`Disc 1/01.mp3` → `Disc 1 - 01.mp3`),
  /// since a volume holds books, not folders. Two paths that flatten to one name get `-2`, `-3`
  /// on the later ones. Also how a volume's book finds the file it plays.
  public static func volumeChildFileNames(_ relativePaths: [String]) -> [String] {
    var used = Set<String>()

    return relativePaths.map { relativePath in
      let flattened = relativePath
        .split(whereSeparator: { $0 == "/" || $0 == "\\" })
        .map(String.init)
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .joined(separator: " - ")

      return uniqueName(sanitize(flattened), used: &used)
    }
  }

  /// `name`, or `<stem>-2.<ext>`, `-3`, … when a sibling already took it.
  static func uniqueName(_ name: String, used: inout Set<String>) -> String {
    var candidate = name
    var suffix = 2
    let (stem, fileExtension) = splitExtension(name)

    while !used.insert(candidate).inserted {
      candidate = fileExtension.isEmpty || stem == name ? "\(name)-\(suffix)" : "\(stem)-\(suffix).\(fileExtension)"
      suffix += 1
    }

    return candidate
  }

  /// `name` split at its last dot, exactly as Android splits it (Kotlin's
  /// `substringBeforeLast('.')` / `substringAfterLast('.', "")`): unlike `NSString`'s path
  /// extension, "Chapter 1. Intro" has the extension " Intro".
  public static func splitExtension(_ name: String) -> (stem: String, fileExtension: String) {
    guard let dot = name.lastIndex(of: ".") else { return (name, "") }

    return (String(name[..<dot]), String(name[name.index(after: dot)...]))
  }
}

/// Why a media-server download couldn't start.
public enum MediaServerDownloadError: LocalizedError, Equatable {
  /// The server answered without a file for the book: the item is gone from it, or several files
  /// were imported as one book (before volumes). Asking again won't change that.
  case noFile
  /// The server rejected the saved token (401).
  case sessionExpired
  /// The server didn't answer in time, or couldn't be reached.
  case unreachable
  /// The server answered with an error: this user may not open the item (403), or it failed.
  case refused

  /// Why a lookup gave no file, or nil when it answered (and only the book's file was missing).
  init?(lookup answer: ExternalStreamFiles) {
    switch answer {
    case .answered:
      return nil
    case .sessionExpired:
      self = .sessionExpired
    case .unreachable:
      self = .unreachable
    case .failed:
      self = .refused
    }
  }

  public var errorDescription: String? {
    switch self {
    case .noFile:
      return "download_error_no_server_file".localized
    case .sessionExpired:
      return "download_error_session_expired".localized
    case .unreachable:
      return "download_error_server_unreachable".localized
    case .refused:
      return "download_error_server_refused".localized
    }
  }
}

/// How a server answered a request for an item's files.
public enum ExternalStreamFiles: Equatable, Sendable {
  /// The item's playable files in play order. Empty when the server has none for it (it's gone).
  case answered([ExternalStreamFile])
  /// The server rejected the saved token (401): the user has to sign in again.
  case sessionExpired
  /// The server didn't answer in time, or couldn't be reached. Asking later may work.
  case unreachable
  /// The server answered with another error: 403 (this user may not open this item), 5xx, or a
  /// page that isn't JSON (a proxy's login page).
  case failed
}

/// Asks a media server for an item's files.
public protocol ExternalStreamLooking: Sendable {
  /// - Parameter timeout: how long to wait for the whole answer. Short on the playback path, so
  ///   an unreachable home server falls through to the cloud copy quickly.
  func files(
    ofItem itemId: String,
    on serverURL: URL,
    headers: [String: String],
    timeout: TimeInterval
  ) async -> ExternalStreamFiles
}

/// How long a lookup waits for its server.
public enum ExternalStreamLookupTimeout {
  /// Someone is waiting to hear the book.
  public static let playback: TimeInterval = 5
  /// A download runs in the background, with nobody waiting on it.
  public static let download: TimeInterval = 30
}

/// AudiobookShelf's files: `GET api/items/{id}?expanded=1`, whose tracks are the item's audio
/// files in play order.
public struct AudiobookShelfStreamLookup: ExternalStreamLooking, BPLogger {
  private let httpClient: IntegrationHTTPClient

  public init(httpClient: IntegrationHTTPClient = IntegrationURLSessionClient()) {
    self.httpClient = httpClient
  }

  public func files(
    ofItem itemId: String,
    on serverURL: URL,
    headers: [String: String],
    timeout: TimeInterval
  ) async -> ExternalStreamFiles {
    var components = URLComponents(
      url: serverURL.appendingPathComponent("api").appendingPathComponent("items").appendingPathComponent(itemId),
      resolvingAgainstBaseURL: false
    )
    components?.queryItems = [URLQueryItem(name: "expanded", value: "1")]
    guard let url = components?.url else { return .failed }

    var request = URLRequest(url: url)
    request.timeoutInterval = timeout
    for (field, value) in headers {
      request.setValue(value, forHTTPHeaderField: field)
    }

    let response: (Data, HTTPURLResponse)
    do {
      guard let answer = try await Self.withTimeout(timeout, operation: { [httpClient] in
        try await httpClient.data(for: request)
      }) else {
        Self.logger.warning("Timed out looking up the files of \(itemId)")
        return .unreachable
      }
      response = answer
    } catch is CancellationError {
      return .failed
    } catch {
      Self.logger.warning("Couldn't reach the server for \(itemId): \(error.localizedDescription)")
      return .unreachable
    }

    let (data, http) = response
    switch http.statusCode {
    case 200...299:
      break
    // Only a 401 means the token is dead. A 403 is this user not being allowed this item (a
    // restricted library or tag), which says nothing about the session or the other items.
    case 401:
      return .sessionExpired
    case 404:
      return .answered([])
    default:
      Self.logger.warning("The server answered the lookup of \(itemId) with \(http.statusCode)")
      return .failed
    }

    // Only the tracks: a field this never reads must not fail the lookup.
    guard let item = try? JSONDecoder().decode(TracksOnly.self, from: data) else {
      Self.logger.warning("The server answered the lookup of \(itemId) with something that isn't an item")
      return .failed
    }

    return .answered(AudiobookShelfAPIItem.Media.Track.streamFiles(itemId: itemId, tracks: item.media?.tracks))
  }

  private struct TracksOnly: Decodable {
    let media: Media?

    struct Media: Decodable {
      let tracks: [AudiobookShelfAPIItem.Media.Track]?
    }
  }

  /// `operation`'s result, or nil when it takes longer than `seconds`. A request's own timeout
  /// only bounds the gaps between packets, not the whole answer.
  private static func withTimeout<T: Sendable>(
    _ seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
  ) async throws -> T? {
    try await withThrowingTaskGroup(of: T?.self) { group in
      group.addTask { try await operation() }
      group.addTask {
        try await Task.sleep(for: .seconds(seconds))
        return nil
      }
      defer { group.cancelAll() }

      return try await group.next() ?? nil
    }
  }
}

/// What a streamed book or volume downloads from its media server: one file per book, with the
/// connection's auth. An AudiobookShelf item's files are looked up now; a volume's books take the
/// files they were named after (`PlayableChapter.StreamLookup`).
struct MediaServerDownloadPlanner {
  struct Download {
    let remoteURL: RemoteFileURL
    /// How to find the file again if it was replaced before its download started. Nil for the
    /// volume's own folder, and for Jellyfin, whose one URL doesn't change.
    let lookup: PlayableChapter.StreamLookup?
  }

  let streamResolver: ExternalStreamResolving
  let streamLookup: ExternalStreamLooking
  /// Everything inside the folder at a path (a volume holds only its books).
  let volumeBooks: (String) -> [SyncableItem]

  /// - Returns: nothing when no saved server matches the link.
  /// - Throws: `MediaServerDownloadError` when the server has no file for the item, rejects the
  ///   token, can't be reached or answers with an error.
  func downloads(for item: SimpleLibraryItem, resource: SimpleExternalResource) async throws -> [Download] {
    guard let source = streamResolver.streamSource(for: resource) else { return [] }

    switch source.location {
    case .url(let url):
      // One URL serves a whole item, so only the item's own book downloads it
      guard item.type == .book else { throw MediaServerDownloadError.noFile }
      return [
        Download(
          remoteURL: RemoteFileURL(url: url, relativePath: item.relativePath, type: .book, headers: source.headers),
          lookup: nil
        )
      ]

    case .audiobookshelfItem(let serverURL, let itemId):
      let answer = await streamLookup.files(
        ofItem: itemId,
        on: serverURL,
        headers: source.headers,
        timeout: ExternalStreamLookupTimeout.download
      )
      guard case .answered(let files) = answer else {
        throw MediaServerDownloadError(lookup: answer) ?? .refused
      }

      let targets: [(relativePath: String, member: PlayableChapter.StreamLookup.Member)]
      if item.type == .book {
        targets = [(item.relativePath, .item)]
      } else {
        let books = volumeBooks(item.relativePath)
          .filter { $0.type == .book && LibraryService.parentPath(of: $0.relativePath) == item.relativePath }
          .sorted { $0.orderRank < $1.orderRank }
        let bookUuids = books.map(\.uuid)
        targets = books.map { book in
          (
            book.relativePath,
            .volumeBook(
              originalFileName: book.originalFileName,
              relativePath: book.relativePath,
              uuid: book.uuid,
              bookUuids: bookUuids
            )
          )
        }
      }

      var downloads = targets.compactMap { target -> Download? in
        let lookup = PlayableChapter.StreamLookup(serverURL: serverURL, itemId: itemId, member: target.member)
        guard let file = lookup.file(in: files) else { return nil }

        return Download(
          remoteURL: RemoteFileURL(
            url: file.url(on: serverURL),
            relativePath: target.relativePath,
            type: .book,
            headers: source.headers
          ),
          lookup: lookup
        )
      }
      // The item is gone from the server, or several files were imported as one book (before
      // volumes): asking again won't change that
      guard !downloads.isEmpty else { throw MediaServerDownloadError.noFile }

      // A volume has no folder on disk until its books land in it
      if item.type == .bound {
        downloads.insert(
          Download(
            remoteURL: RemoteFileURL(url: serverURL, relativePath: item.relativePath, type: .bound, headers: nil),
            lookup: nil
          ),
          at: 0
        )
      }

      return downloads
    }
  }
}
