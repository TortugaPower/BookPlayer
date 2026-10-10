//
//  PlayableChapter.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 27/11/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import Foundation
import UniformTypeIdentifiers

public struct PlayableChapter: Codable, Identifiable {
  /// The media server a chapter streams from, when no saved connection on this device matches
  /// it: what the missing-server alert can tell the user about it.
  public struct UnresolvedHost: Equatable {
    public let provider: ExternalResource.MediaServerProvider?
    /// The server's address, when the resource's `hostId` is one: every AudiobookShelf book a
    /// current build imports (ABS has no instance id), and a Jellyfin book whose server never
    /// reported its id. Nil for an id-shaped hostId (a Jellyfin GUID, or the
    /// `"server-settings"` constant older Android builds stored for every ABS server), which
    /// tells the user nothing.
    public let address: String?

    public init(provider: ExternalResource.MediaServerProvider?, address: String?) {
      self.provider = provider
      self.address = address
    }

    public init(resource: SimpleExternalResource) {
      let hostId = resource.hostId ?? ""
      let isAddress = ["http://", "https://"].contains {
        hostId.range(of: $0, options: [.caseInsensitive, .anchored]) != nil
      }

      self.init(provider: resource.mediaServer, address: isAddress ? hostId : nil)
    }
  }

  /// What to ask an AudiobookShelf server for to play a chapter: its file can't be named until
  /// asked, so `PlayerManager` looks it up when the chapter loads.
  public struct StreamLookup: Equatable, Sendable {
    public enum Member: Equatable, Sendable {
      /// The linked book itself, which plays the item's only file. An item with several files
      /// that was imported as one book (before volumes) has none to play.
      case item
      /// A book of a streamed volume: the file its name was made from, else the one at its
      /// position when the volume holds as many books as the item has files.
      case volumeBook(fileName: String, position: Int, bookCount: Int)

      /// A volume's book: named `originalFileName` at import (else its path's last component),
      /// at its place among the volume's books in play order, `bookUuids`.
      public static func volumeBook(
        originalFileName: String,
        relativePath: String,
        uuid: String,
        bookUuids: [String]
      ) -> Member {
        .volumeBook(
          fileName: originalFileName.isEmpty ? (relativePath as NSString).lastPathComponent : originalFileName,
          position: bookUuids.firstIndex(of: uuid) ?? -1,
          bookCount: bookUuids.count
        )
      }
    }

    public let serverURL: URL
    public let itemId: String
    public let member: Member

    public init(serverURL: URL, itemId: String, member: Member) {
      self.serverURL = serverURL
      self.itemId = itemId
      self.member = member
    }

    /// The file this chapter plays among the item's `files`, or nil when there's none for it.
    public func file(in files: [ExternalStreamFile]) -> ExternalStreamFile? {
      switch member {
      case .item:
        return files.count == 1 ? files.first : nil
      case .volumeBook(let fileName, let position, let bookCount):
        // The names its books were imported under, rebuilt from the server's current files
        let names = MediaServerFileNames.volumeChildFileNames(files.map(\.name))
        if let index = names.firstIndex(of: fileName) {
          return files[index]
        }

        return bookCount == files.count && files.indices.contains(position) ? files[position] : nil
      }
    }
  }

  public var id: String {
    return "\(index)"
  }
  public let title: String
  public let author: String
  public let start: TimeInterval
  public let duration: TimeInterval
  public let relativePath: String
  public let remoteURL: URL?
  public let externalUrl: URL?
  public let index: Int16
  public let chapterOffset: TimeInterval
  public let externalHeaders: [String: String]
  /// Set for an AudiobookShelf chapter whose server is saved here, sent with `externalHeaders`.
  /// Jellyfin's single URL is `externalUrl`.
  public let streamLookup: StreamLookup?
  /// Set when the item carries a media-server resource but no saved connection on THIS
  /// device matches its host, so there is no external URL to stream and nothing to download.
  public let unresolvedHost: UnresolvedHost?

  /// Distinct from `externalUrl == nil`, which is also true for items that never had a media
  /// server at all.
  public var hasUnresolvedExternalHost: Bool {
    unresolvedHost != nil
  }

  public var end: TimeInterval {
    return start + duration
  }

  public var fileURL: URL {
    return DataManager.getProcessedFolderURL().appendingPathComponent(self.relativePath)
  }

  /// Whether the chapter's file is a video, based on its file extension.
  /// Derives the type from `relativePath` directly rather than `fileURL`, which
  /// would resolve (and create) the processed folder just to read a path extension.
  public var isVideo: Bool {
    URL(fileURLWithPath: relativePath).fileType?.conforms(to: .movie) ?? false
  }

  /// The file isn't on disk and only a media server can supply it: either its stream URL
  /// resolved (and the load still failed, so the token or the server is the problem) or no
  /// saved connection matches its host, meaning the server was never added here.
  ///
  /// A function rather than a property because it stats the filesystem.
  public func needsMediaServer() -> Bool {
    guard !FileManager.default.fileExists(atPath: fileURL.path) else { return false }

    return isStreamed || hasUnresolvedExternalHost
  }

  /// A saved media server can serve the chapter: by its URL, or by asking for its file.
  public var isStreamed: Bool {
    externalUrl != nil || streamLookup != nil
  }

  public init(
    title: String,
    author: String,
    start: TimeInterval,
    duration: TimeInterval,
    relativePath: String,
    remoteURL: URL?,
    externalURL: URL?,
    index: Int16,
    chapterOffset: TimeInterval = 0,
    externalHeaders: [String: String] = [:],
    streamLookup: StreamLookup? = nil,
    unresolvedHost: UnresolvedHost? = nil
  ) {
    self.title = title
    self.author = author
    self.start = start
    self.duration = duration
    self.relativePath = relativePath
    self.remoteURL = remoteURL
    self.externalUrl = externalURL
    self.index = index
    self.chapterOffset = chapterOffset
    self.externalHeaders = externalHeaders
    self.streamLookup = streamLookup
    self.unresolvedHost = unresolvedHost
  }

  /// `externalUrl`/`externalHeaders`/`streamLookup`/`unresolvedHost` are deliberately EXCLUDED from Codable: the headers carry
  /// the media server's live `Authorization` token, and encoded `PlayableItem`s travel through
  /// the WatchConnectivity application context, which the system PERSISTS TO DISK on both
  /// devices. Both values are per-device, resolved from the local connection at load time
  /// (`PlaybackService.getPlayableChapters`), so there is nothing to transport — the receiving
  /// side re-resolves against its own saved connections.
  enum CodingKeys: String, CodingKey {
    case title, author, start, duration, relativePath, remoteURL, index, chapterOffset
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.title = try container.decode(String.self, forKey: .title)
    self.author = try container.decode(String.self, forKey: .author)
    self.start = try container.decode(TimeInterval.self, forKey: .start)
    self.duration = try container.decode(TimeInterval.self, forKey: .duration)
    self.relativePath = try container.decode(String.self, forKey: .relativePath)
    self.remoteURL = try container.decodeIfPresent(URL.self, forKey: .remoteURL)
    self.index = try container.decode(Int16.self, forKey: .index)
    self.chapterOffset = (try? container.decodeIfPresent(TimeInterval.self, forKey: .chapterOffset)) ?? 0
    self.externalUrl = nil
    self.externalHeaders = [:]
    self.streamLookup = nil
    self.unresolvedHost = nil
  }
}

extension PlayableChapter: Equatable {
  public static func == (lhs: PlayableChapter, rhs: PlayableChapter) -> Bool {
    return lhs.relativePath == rhs.relativePath
      && lhs.index == rhs.index
      && lhs.title == rhs.title
      && lhs.start == rhs.start
  }
}
