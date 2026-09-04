//
//  AudiobookShelfLibraryItem.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 14/11/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import Foundation

public struct AudiobookShelfSeriesReference: Codable, Hashable {
  let id: String
  let name: String
  let sequence: String?
}

public struct AudiobookShelfLibraryItem: IntegrationLibraryItemProtocol, Codable {
  public enum Kind: String, Codable {
    case audiobook = "book"
    case podcast = "podcast"
    case library = "library"
    case browseCategory = "browseCategory"
    case series = "series"
    case collection = "collection"
    case author = "author"
    case narrator = "narrator"
  }

  public let id: String
  public let title: String
  public let kind: Kind
  public let libraryId: String

  // Metadata
  public let authorName: String?
  public let narratorName: String?
  public let duration: TimeInterval?
  public let size: Int64?
  public let subtitle: String?
  public let series: [AudiobookShelfSeriesReference]?
  public let addedAt: Int64?
  public let updatedAt: Int64?
  public let fileExtension: String?
  
  // Cover image
  public let coverPath: String?
  public let coverItemId: String?

  // Progress (if included)
  public let progress: Double?
  public let currentTime: TimeInterval?
  public let isFinished: Bool?
  /// From the progress payload's lastUpdate (ms epoch) — drives the resume-playback
  /// prompt's date comparison, same as Jellyfin's lastPlayedDate
  public let lastPlayedDate: Date?

  // Browse metadata
  public let browseCategory: AudiobookShelfBrowseCategory?
  public let filter: AudiobookShelfItemFilter?

  public init(
    id: String,
    title: String,
    kind: Kind,
    libraryId: String,
    authorName: String? = nil,
    narratorName: String? = nil,
    duration: TimeInterval? = nil,
    size: Int64? = nil,
    subtitle: String? = nil,
    series: [AudiobookShelfSeriesReference]? = nil,
    addedAt: Int64? = nil,
    fileExtension: String? = nil,
    updatedAt: Int64? = nil,
    coverPath: String? = nil,
    coverItemId: String? = nil,
    progress: Double? = nil,
    currentTime: TimeInterval? = nil,
    isFinished: Bool? = nil,
    lastPlayedDate: Date? = nil,
    browseCategory: AudiobookShelfBrowseCategory? = nil,
    filter: AudiobookShelfItemFilter? = nil
  ) {
    self.id = id
    self.title = title
    self.kind = kind
    self.libraryId = libraryId
    self.authorName = authorName
    self.narratorName = narratorName
    self.duration = duration
    self.size = size
    self.subtitle = subtitle
    self.series = series
    self.fileExtension = fileExtension
    self.addedAt = addedAt
    self.updatedAt = updatedAt
    self.coverPath = coverPath
    self.coverItemId = coverItemId
    self.progress = progress
    self.currentTime = currentTime
    self.isFinished = isFinished
    self.lastPlayedDate = lastPlayedDate
    self.browseCategory = browseCategory
    self.filter = filter
  }
}

extension AudiobookShelfLibraryItem {
  public var displayName: String { title }

  public var isDownloadable: Bool {
    kind == .audiobook || kind == .podcast
  }

  public var isNavigable: Bool {
    !isDownloadable
  }

  public var placeholderImageName: String {
    switch kind {
    case .podcast, .audiobook: "waveform"
    case .library: "folder"
    case .browseCategory:
      switch browseCategory {
      case .books: "books.vertical"
      case .series: "rectangle.stack"
      case .collections: "square.stack.3d.up"
      case .authors: "person.2"
      case .narrators: "mic"
      case .none: "square.grid.2x2"
      }
    case .series: "rectangle.stack"
    case .collection: "square.stack.3d.up"
    case .author: "person"
    case .narrator: "mic"
    }
  }

  public func seriesSequence(for seriesID: String) -> String? {
    series?.first(where: { $0.id == seriesID })?.sequence
  }

  public init(library: AudiobookShelfLibrary) {
    self.init(
      id: library.id,
      title: library.name,
      kind: .library,
      libraryId: library.id,
      subtitle: library.mediaType == "podcast" ? "Podcast library" : "Audiobook library"
    )
  }

  public init(category: AudiobookShelfBrowseCategory, libraryId: String) {
    self.init(
      id: category.rawValue,
      title: category.title,
      kind: .browseCategory,
      libraryId: libraryId,
      subtitle: "Browse by \(category.title.lowercased())",
      browseCategory: category
    )
  }

  public init(author: AudiobookShelfLibraryFilterData.NamedEntity, libraryId: String) {
    self.init(
      id: author.id,
      title: author.name,
      kind: .author,
      libraryId: libraryId,
      subtitle: "Author",
      filter: AudiobookShelfItemFilter(group: .authors, value: author.id, title: author.name)
    )
  }

  public init(series: AudiobookShelfLibraryFilterData.NamedEntity, libraryId: String) {
    self.init(
      id: series.id,
      title: series.name,
      kind: .series,
      libraryId: libraryId,
      subtitle: "Series",
      filter: AudiobookShelfItemFilter(group: .series, value: series.id, title: series.name)
    )
  }

  public init(narrator: String, libraryId: String) {
    self.init(
      id: narrator,
      title: narrator,
      kind: .narrator,
      libraryId: libraryId,
      subtitle: "Narrator",
      filter: AudiobookShelfItemFilter(group: .narrators, value: narrator, title: narrator)
    )
  }

  public init(collection: AudiobookShelfCollection) {
    self.init(
      id: collection.id,
      title: collection.name,
      kind: .collection,
      libraryId: collection.libraryId,
      subtitle: collection.description ?? "\(collection.books.count) books",
      coverItemId: collection.books.first?.id
    )
  }

  public init?(apiItem: AudiobookShelfAPIItem) {
    guard let mediaType = apiItem.mediaType,
          let kind = Kind(rawValue: mediaType) else {
      return nil
    }
    self.init(
      id: apiItem.id,
      title: apiItem.media.metadata.title,
      kind: kind,
      libraryId: apiItem.libraryId,
      authorName: apiItem.media.metadata.primaryAuthorName,
      narratorName: apiItem.media.metadata.primaryNarratorName,
      duration: apiItem.media.duration,
      size: apiItem.size,
      series: apiItem.media.metadata.series,
      addedAt: apiItem.addedAt,
      fileExtension: apiItem.media.audioFiles?.first?.normalizedExtension,
      updatedAt: apiItem.updatedAt,
      coverPath: apiItem.media.coverPath,
      progress: apiItem.userMediaProgress?.progress,
      currentTime: apiItem.userMediaProgress?.currentTime,
      isFinished: apiItem.userMediaProgress?.isFinished
    )
  }
  
  public init(progressItem: AudiobookShelfAPIItem.UserMediaProgress) {
    self.init(
      id: "",
      title: "",
      kind: Kind.audiobook,
      libraryId: "",
      progress: progressItem.progress,
      currentTime: progressItem.currentTime,
      isFinished: progressItem.isFinished,
      lastPlayedDate: progressItem.lastUpdate.map { Date(timeIntervalSince1970: $0 / 1000) }
    )
  }
}

// MARK: - API Response Models

public struct AudiobookShelfAPIItem: Codable {
  public let id: String
  public let libraryId: String
  public let addedAt: Int64?
  public let updatedAt: Int64?
  public let mediaType: String?
  public let media: Media
  public let size: Int64?
  public let userMediaProgress: UserMediaProgress?
  public let relPath: String?
  
  public struct Media: Codable {
    public let metadata: Metadata
    public let coverPath: String?
    public let duration: TimeInterval?
    public let audioFiles: [AudioFile]?
    
    public struct Metadata: Codable {
      public let title: String
      public let authorName: String?
      public let narratorName: String?
      public let authors: [NamedEntity]?
      public let narrators: [String]?
      public let series: [AudiobookShelfSeriesReference]?

      public enum CodingKeys: String, CodingKey {
        case title
        case authorName
        case narratorName
        case authors
        case narrators
        case series
      }

      public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        title = try container.decode(String.self, forKey: .title)
        authorName = try container.decodeIfPresent(String.self, forKey: .authorName)
        narratorName = try container.decodeIfPresent(String.self, forKey: .narratorName)
        authors = try container.decodeIfPresent([NamedEntity].self, forKey: .authors)
        narrators = try container.decodeIfPresent([String].self, forKey: .narrators)

        if let seriesArray = try? container.decode([AudiobookShelfSeriesReference].self, forKey: .series) {
          series = seriesArray
        } else if let seriesSingle = try? container.decode(AudiobookShelfSeriesReference.self, forKey: .series) {
          series = [seriesSingle]
        } else {
          series = nil
        }
      }

      public var primaryAuthorName: String? {
        authorName ?? authors?.first?.name
      }

      public var primaryNarratorName: String? {
        narratorName ?? narrators?.first
      }
    }

    public struct NamedEntity: Codable {
      public let id: String
      public let name: String
    }
    
    public struct AudioFile: Codable {
      // ABS nests file fields under metadata (AudioFile.toJSON in the server:
      // { index, ino, metadata: { filename, ext, path, ... }, ... }) — a top-level
      // filename/ext shape can never decode a real expanded payload.
      public let metadata: FileMetadata

      public struct FileMetadata: Codable {
        public let filename: String
        /// Dot-prefixed on the wire (".m4b") — normalize via `normalizedExtension`.
        public let ext: String
      }
    }
  }

  public struct UserMediaProgress: Codable {
    public let progress: Double
    public let currentTime: TimeInterval
    public let isFinished: Bool
    /// Milliseconds since epoch of the last progress update
    public let lastUpdate: Double?
  }
}

public struct AudiobookShelfItemsResponse: Codable {
  public let results: [AudiobookShelfAPIItem]
  public let total: Int
  public let limit: Int?
  public let page: Int?
}

/// Response of POST /api/items/batch/get — expanded items incl. media.audioFiles
public struct AudiobookShelfBatchItemsResponse: Codable {
  public let libraryItems: [AudiobookShelfAPIItem]?
}

public struct AudiobookShelfSearchResponse: Codable {
  public let book: [SearchResult]

  public struct SearchResult: Codable {
    public let libraryItem: AudiobookShelfAPIItem
  }
}

/// Response from `GET /api/authors/:id?include=items` (the endpoint the official
/// Vue web client uses for the author-detail page). `libraryItems` is hydrated
/// directly from the author record rather than via the `bookAuthors` join, which
/// avoids orphan-row matches that can occur after ABS dedups authors on import.
public struct AudiobookShelfAuthorWithItemsResponse: Codable {
  public let id: String
  public let name: String
  public let libraryItems: [AudiobookShelfAPIItem]?
}

public struct AudiobookShelfLibraryFilterData: Codable {
  public let authors: [NamedEntity]
  public let genres: [String]
  public let tags: [String]
  public let series: [NamedEntity]
  public let narrators: [String]
  public let languages: [String]

  public struct NamedEntity: Codable, Hashable {
    public let id: String
    public let name: String
  }
}

public struct AudiobookShelfCollection: Codable {
  public let id: String
  public let libraryId: String
  public let name: String
  public let description: String?
  public let books: [AudiobookShelfAPIItem]
}

public struct AudiobookShelfCollectionsResponse: Codable {
  public let results: [AudiobookShelfCollection]
}

// MARK: - Virtual import

extension AudiobookShelfLibraryItem {
  /// Builds the virtual-import payload for this item. The file extension is REQUIRED:
  /// list endpoints return minified items without audio-file metadata, so callers
  /// hydrate the selection via `fetchItems(ids:)` (POST /api/items/batch/get) and SKIP
  /// items that have none — the extension is never guessed.
  @MainActor
  public func asVirtualImportResource(
    fileExtension: String,
    connectionService: AudiobookShelfConnectionService,
    artworkSize: CGSize
  ) -> SimpleExternalResource {
    let libraryItem = SimpleLibraryItem(
      title: title,
      details: authorName ?? "voiceover_unknown_author".localized,
      speed: 1,
      currentTime: Double(currentTime ?? 0),
      duration: Double(duration ?? 0),
      percentCompleted: (progress ?? 0) > 0 && (duration ?? 0) > 0
        ? Double(progress!) * 100
        : 0,
      isFinished: isFinished ?? false,
      relativePath: "",
      remoteURL: nil,
      artworkURL: connectionService.createItemImageURL(self, size: artworkSize),
      orderRank: 0,
      parentFolder: nil,
      originalFileName: "\(title).\(fileExtension)",
      lastPlayDate: nil,
      type: .book,
      uuid: UUID().uuidString
    )

    return SimpleExternalResource(
      id: abs(UUID().hashValue),  // unique per element — a shared timestamp collides Identifiable ids within a batch
      providerName: ExternalResource.ProviderName.audiobookshelf.rawValue,
      providerId: id,
      syncStatus: ExternalResource.SyncStatus.stream.rawValue,
      lastSyncedAt: nil,
      hostId: connectionService.connection?.stableHostId,
      libraryItem: libraryItem
    )
  }
}

extension AudiobookShelfAPIItem.Media.AudioFile {
  /// ABS's `metadata.ext` is dot-prefixed (".m4b", server FileMetadata semantics);
  /// BookPlayer composes filenames as "title.ext", so the dot must be stripped or
  /// every ABS virtual import is named "Title..m4b". Empty ext maps to nil so the
  /// import pipeline's skip contract (no extension = not importable) still holds.
  public var normalizedExtension: String? {
    let trimmed = metadata.ext.hasPrefix(".") ? String(metadata.ext.dropFirst()) : metadata.ext
    return trimmed.isEmpty ? nil : trimmed
  }
}
