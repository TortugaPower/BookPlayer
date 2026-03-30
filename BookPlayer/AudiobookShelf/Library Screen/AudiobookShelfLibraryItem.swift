//
//  AudiobookShelfLibraryItem.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 14/11/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import Foundation

struct AudiobookShelfSeriesReference: Codable, Hashable {
  let id: String
  let name: String
  let sequence: String?
}

struct AudiobookShelfLibraryItem: Identifiable, Hashable, Codable {
  enum Kind: String, Codable {
    case audiobook = "book"
    case podcast = "podcast"
    case library = "library"
    case browseCategory = "browseCategory"
    case series = "series"
    case collection = "collection"
    case author = "author"
    case narrator = "narrator"
  }

  let id: String
  let title: String
  let kind: Kind
  let libraryId: String

  // Metadata
  let authorName: String?
  let narratorName: String?
  let duration: TimeInterval?
  let size: Int64?
  let subtitle: String?
  let series: [AudiobookShelfSeriesReference]?
  let addedAt: Int64?
  let updatedAt: Int64?

  // Cover image
  let coverPath: String?
  let coverItemId: String?

  // Progress (if included)
  let progress: Double?
  let currentTime: TimeInterval?
  let isFinished: Bool?

  // Browse metadata
  let browseCategory: AudiobookShelfBrowseCategory?
  let filter: AudiobookShelfItemFilter?

  init(
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
  var isDownloadable: Bool {
    kind == .audiobook || kind == .podcast
  }

  var isNavigable: Bool {
    !isDownloadable
  }

  var placeholderImageName: String {
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

  func seriesSequence(for seriesID: String) -> String? {
    series?.first(where: { $0.id == seriesID })?.sequence
  }

  init(library: AudiobookShelfLibrary) {
    self.init(
      id: library.id,
      title: library.name,
      kind: .library,
      libraryId: library.id,
      subtitle: library.mediaType == "podcast" ? "Podcast library" : "Audiobook library"
    )
  }

  init(category: AudiobookShelfBrowseCategory, libraryId: String) {
    self.init(
      id: category.rawValue,
      title: category.title,
      kind: .browseCategory,
      libraryId: libraryId,
      subtitle: "Browse by \(category.title.lowercased())",
      browseCategory: category
    )
  }

  init(author: AudiobookShelfLibraryFilterData.NamedEntity, libraryId: String) {
    self.init(
      id: author.id,
      title: author.name,
      kind: .author,
      libraryId: libraryId,
      subtitle: "Author",
      filter: AudiobookShelfItemFilter(group: .authors, value: author.id, title: author.name)
    )
  }

  init(series: AudiobookShelfLibraryFilterData.NamedEntity, libraryId: String) {
    self.init(
      id: series.id,
      title: series.name,
      kind: .series,
      libraryId: libraryId,
      subtitle: "Series",
      filter: AudiobookShelfItemFilter(group: .series, value: series.id, title: series.name)
    )
  }

  init(narrator: String, libraryId: String) {
    self.init(
      id: narrator,
      title: narrator,
      kind: .narrator,
      libraryId: libraryId,
      subtitle: "Narrator",
      filter: AudiobookShelfItemFilter(group: .narrators, value: narrator, title: narrator)
    )
  }

  init(collection: AudiobookShelfCollection) {
    self.init(
      id: collection.id,
      title: collection.name,
      kind: .collection,
      libraryId: collection.libraryId,
      subtitle: collection.description ?? "\(collection.books.count) books",
      coverItemId: collection.books.first?.id
    )
  }

  init?(apiItem: AudiobookShelfAPIItem) {
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
      updatedAt: apiItem.updatedAt,
      coverPath: apiItem.media.coverPath,
      progress: apiItem.userMediaProgress?.progress,
      currentTime: apiItem.userMediaProgress?.currentTime,
      isFinished: apiItem.userMediaProgress?.isFinished
    )
  }
}

// MARK: - API Response Models

struct AudiobookShelfAPIItem: Codable {
  let id: String
  let libraryId: String
  let addedAt: Int64?
  let updatedAt: Int64?
  let mediaType: String?
  let media: Media
  let size: Int64?
  let userMediaProgress: UserMediaProgress?

  struct Media: Codable {
    let metadata: Metadata
    let coverPath: String?
    let duration: TimeInterval?

    struct Metadata: Codable {
      let title: String
      let authorName: String?
      let narratorName: String?
      let authors: [NamedEntity]?
      let narrators: [String]?
      let series: [AudiobookShelfSeriesReference]?

      enum CodingKeys: String, CodingKey {
        case title
        case authorName
        case narratorName
        case authors
        case narrators
        case series
      }

      init(from decoder: Decoder) throws {
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

      var primaryAuthorName: String? {
        authorName ?? authors?.first?.name
      }

      var primaryNarratorName: String? {
        narratorName ?? narrators?.first
      }
    }

    struct NamedEntity: Codable {
      let id: String
      let name: String
    }
  }

  struct UserMediaProgress: Codable {
    let progress: Double
    let currentTime: TimeInterval
    let isFinished: Bool
  }
}

struct AudiobookShelfItemsResponse: Codable {
  let results: [AudiobookShelfAPIItem]
  let total: Int
  let limit: Int?
  let page: Int?
}

struct AudiobookShelfSearchResponse: Codable {
  let book: [SearchResult]

  struct SearchResult: Codable {
    let libraryItem: AudiobookShelfAPIItem
  }
}

struct AudiobookShelfLibraryFilterData: Codable {
  let authors: [NamedEntity]
  let genres: [String]
  let tags: [String]
  let series: [NamedEntity]
  let narrators: [String]
  let languages: [String]

  struct NamedEntity: Codable, Hashable {
    let id: String
    let name: String
  }
}

struct AudiobookShelfCollection: Codable {
  let id: String
  let libraryId: String
  let name: String
  let description: String?
  let books: [AudiobookShelfAPIItem]
}

struct AudiobookShelfCollectionsResponse: Codable {
  let results: [AudiobookShelfCollection]
}
