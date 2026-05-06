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
    let fileExtension = apiItem.relPath?.split(separator: ".").last?.description ?? nil

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
      fileExtension: fileExtension,
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
      isFinished: progressItem.isFinished
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
  }

  public struct UserMediaProgress: Codable {
    public let progress: Double
    public let currentTime: TimeInterval
    public let isFinished: Bool
  }
}

public struct AudiobookShelfItemsResponse: Codable {
  public let results: [AudiobookShelfAPIItem]
  public let total: Int
  public let limit: Int?
  public let page: Int?
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
