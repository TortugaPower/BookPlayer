//
//  AudiobookShelfLibraryItem.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 14/11/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import Foundation

struct AudiobookShelfLibraryItem: Identifiable, Hashable, Codable {
  enum Kind: String, Codable {
    case audiobook = "book"
    case podcast = "podcast"
    case library = "library"
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
  
  // Cover image
  let coverPath: String?
  
  // Progress (if included)
  let progress: Double?
  let currentTime: TimeInterval?
  let isFinished: Bool?
  
  init(
    id: String,
    title: String,
    kind: Kind,
    libraryId: String,
    authorName: String? = nil,
    narratorName: String? = nil,
    duration: TimeInterval? = nil,
    size: Int64? = nil,
    coverPath: String? = nil,
    progress: Double? = nil,
    currentTime: TimeInterval? = nil,
    isFinished: Bool? = nil
  ) {
    self.id = id
    self.title = title
    self.kind = kind
    self.libraryId = libraryId
    self.authorName = authorName
    self.narratorName = narratorName
    self.duration = duration
    self.size = size
    self.coverPath = coverPath
    self.progress = progress
    self.currentTime = currentTime
    self.isFinished = isFinished
  }
}

extension AudiobookShelfLibraryItem {
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
      authorName: apiItem.media.metadata.authorName,
      narratorName: apiItem.media.metadata.narratorName,
      duration: apiItem.media.duration,
      size: apiItem.size,
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
