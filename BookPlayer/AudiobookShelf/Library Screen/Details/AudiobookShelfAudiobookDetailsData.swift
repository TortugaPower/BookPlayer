//
//  AudiobookShelfAudiobookDetailsData.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 14/11/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation

struct AudiobookShelfAudiobookDetailsData {
  let artist: String?
  let narrator: String?
  let filePath: String?
  let fileSize: Int64?
  let overview: String?
  let runtimeInSeconds: TimeInterval?
  let genres: [String]?
  let tags: [String]?
  let publishedYear: String?
  let publisher: String?
  let series: [Series]?
  
  struct Series: Identifiable, Hashable {
    let id: String
    let name: String
    let sequence: String?
  }
  
  var runtimeString: String {
    guard let runtime = runtimeInSeconds else {
      return "runtime_unknown".localized
    }
    return TimeParser.formatTotalDuration(runtime)
  }
  
  var fileSizeString: String {
    guard let size = fileSize else {
      return "file_size_unknown".localized
    }
    return ByteCountFormatter.string(
      fromByteCount: size,
      countStyle: ByteCountFormatter.CountStyle.file
    )
  }
}

// MARK: - API Response Model

struct AudiobookShelfItemDetailsResponse: Codable {
  let id: String
  let libraryId: String
  let media: Media
  let libraryFiles: [LibraryFile]
  let size: Int64?
  
  struct Media: Codable {
    let metadata: Metadata
    let coverPath: String?
    let tags: [String]?
    let audioFiles: [AudioFile]?
    let chapters: [Chapter]?
    let duration: TimeInterval?
    let size: Int64?
    
    struct Metadata: Codable {
      let title: String
      let subtitle: String?
      let authors: [Author]?
      let narrators: [String]?
      let series: [Series]?
      let genres: [String]?
      let publishedYear: String?
      let publisher: String?
      let description: String?
      let isbn: String?
      let asin: String?
      let language: String?
      let explicit: Bool?
      let authorName: String?
      let narratorName: String?
    }
    
    struct Author: Codable {
      let id: String
      let name: String
    }
    
    struct Series: Codable {
      let id: String
      let name: String
      let sequence: String?
    }
    
    struct AudioFile: Codable {
      let index: Int
      let ino: String
      let metadata: FileMetadata
      let duration: TimeInterval
      let format: String?
      let bitRate: Int?
      
      struct FileMetadata: Codable {
        let filename: String
        let ext: String
        let path: String
        let size: Int64
      }
    }
    
    struct Chapter: Codable {
      let id: Int
      let start: TimeInterval
      let end: TimeInterval
      let title: String
    }
  }
  
  struct LibraryFile: Codable {
    let ino: String
    let metadata: FileMetadata
    let fileType: String
    
    struct FileMetadata: Codable {
      let filename: String
      let ext: String
      let path: String
      let size: Int64
    }
  }
}

extension AudiobookShelfAudiobookDetailsData {
  init(apiResponse: AudiobookShelfItemDetailsResponse) {
    let metadata = apiResponse.media.metadata
    
    self.artist = metadata.authorName ?? metadata.authors?.first?.name
    self.narrator = metadata.narratorName ?? metadata.narrators?.first
    
    // Get file path from first audio file
    self.filePath = apiResponse.media.audioFiles?.first?.metadata.path
    self.fileSize = apiResponse.size
    self.overview = metadata.description
    self.runtimeInSeconds = apiResponse.media.duration
    self.genres = metadata.genres
    self.tags = apiResponse.media.tags
    self.publishedYear = metadata.publishedYear
    self.publisher = metadata.publisher
    self.series = metadata.series?.map { apiSeries in
      Series(id: apiSeries.id, name: apiSeries.name, sequence: apiSeries.sequence)
    }
  }
}
