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
  /// The server's chapter list, empty unless this item came from an EXPANDED payload.
  /// A streamed item has no other source: nothing opens the file to read embedded ones,
  /// and ABS chapters can be server-side edits that aren't in the file at all.
  public let chapters: [ChapterMetadata]
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
    chapters: [ChapterMetadata] = [],
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
    self.chapters = chapters
    self.browseCategory = browseCategory
    self.filter = filter
  }
}

extension AudiobookShelfLibraryItem {
  public var displayName: String { title }

  public var isDownloadable: Bool {
    kind == .audiobook
  }

  public var isNavigable: Bool {
    !isDownloadable
  }

  public var placeholderImageName: String {
    switch kind {
    case .audiobook: "waveform"
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
      isFinished: apiItem.userMediaProgress?.isFinished,
      chapters: Self.chapterMetadata(from: apiItem.media.chapters, duration: apiItem.media.duration)
    )
  }

  /// ABS gives every chapter a start AND an end, so durations are direct — but the list is
  /// taken verbatim from the media and need not reach the item's end: an m4b whose embedded
  /// chapter track stops before the trailing silence or credits leaves a gap, since
  /// `media.duration` sums the audio files while `media.chapters` does not.
  ///
  /// The LAST chapter is therefore stretched to the item duration, giving the same total
  /// coverage the Jellyfin mapping has by construction. Without it a position in that gap
  /// resolves to no chapter, and `PlayableItem.init` falls back to `chapters[0]` — pinning
  /// the whole session to chapter 1, which then never advances (the tick only reassigns when
  /// `getChapter` finds one) and never reaches `chapters.last`, so the book never completes.
  ///
  /// Entries that don't describe a positive span are dropped: `getPlayableChapters` filters
  /// those anyway, and storing them would make the stored list disagree with the playable one.
  static func chapterMetadata(
    from chapters: [AudiobookShelfAPIItem.Media.Chapter]?,
    duration: TimeInterval?
  ) -> [ChapterMetadata] {
    guard let chapters else { return [] }

    // Degenerate entries go FIRST, so the stretch below lands on a real chapter — stretching
    // whatever happened to sort last would resurrect a zero-length one and overlap its
    // predecessor.
    let usable = chapters
      .filter { chapter in
        guard chapter.end > chapter.start else { return false }
        guard let duration else { return true }
        return chapter.start < duration
      }
      .sorted { $0.start < $1.start }

    return usable.enumerated().map { index, chapter in
      let isLast = index == usable.count - 1
      let end: TimeInterval
      if let duration, isLast || chapter.end > duration {
        end = duration
      } else {
        end = chapter.end
      }

      return ChapterMetadata(
        title: chapter.title,
        start: chapter.start,
        duration: end - chapter.start,
        index: index + 1
      )
    }
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
    /// Present on EXPANDED media only, alongside `audioFiles` — which is exactly what
    /// `POST /api/items/batch/get` returns. These are the server's chapters, which the
    /// user may have edited in ABS and which a multi-file book has instead of embedded
    /// ones, so they are the authoritative list for an item we only ever stream.
    public let chapters: [Chapter]?

    /// Only the fields we read, like `AudioFile` below: a malformed element we never look at
    /// would otherwise throw and take the whole batch response — and the import with it.
    public struct Chapter: Codable {
      public let start: TimeInterval
      public let end: TimeInterval
      public let title: String
    }
    
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
  /// Builds the virtual-import payload for this item. The file extension and the duration
  /// are REQUIRED and both come from hydration (`VirtualImportPipeline`): list endpoints
  /// return minified items without audio-file metadata, so callers hydrate the selection
  /// via `fetchItems(ids:)` (POST /api/items/batch/get) and SKIP items that have neither
  /// a real extension nor a measured length — the extension is never guessed, and the
  /// duration is never defaulted to 0, which would import an unplayable row.
  @MainActor
  public func asVirtualImportResource(
    fileExtension: String,
    duration: TimeInterval,
    chapters: [ChapterMetadata] = [],
    connectionService: AudiobookShelfConnectionService,
    artworkSize: CGSize
  ) -> SimpleExternalResource {
    let libraryItem = SimpleLibraryItem(
      title: title,
      details: authorName ?? "voiceover_unknown_author".localized,
      speed: 1,
      currentTime: Double(currentTime ?? 0),
      duration: duration,
      /// ABS reports progress as a 0-1 fraction; the duration gate the old expression
      /// carried is now the pipeline's precondition.
      percentCompleted: max(progress ?? 0, 0) * 100,
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
      libraryItem: libraryItem,
      chapters: chapters
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
