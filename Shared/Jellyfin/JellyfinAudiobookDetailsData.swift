//
//  JellyfinDetailsData.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 23/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

public struct JellyfinAudiobookDetailsData {
  public let artist: String?
  public let filePath: String?
  public let fileSize: Int?
  public let overview: String?
  public let runtimeInSeconds: TimeInterval?
  public let genres: [String]?
  public let tags: [String]?

  public var fileSizeString: String {
    if let fileSize {
      ByteCountFormatter.string(
        fromByteCount: Int64(fileSize),
        countStyle: ByteCountFormatter.CountStyle.file
      )
    } else {
      "file_size_unknown".localized
    }
  }

  public var runtimeString: String {
    if let runtimeInSeconds {
      return TimeParser.formatTotalDuration(runtimeInSeconds)
    } else {
      return "runtime_unknown".localized
    }
  }
  
  public init(
    artist: String? = nil,
    filePath: String? = nil,
    fileSize: Int? = nil,
    overview: String? = nil,
    runtimeInSeconds: TimeInterval? = nil,
    genres: [String]? = nil,
    tags: [String]? = nil
  ) {
    self.artist = artist
    self.filePath = filePath
    self.fileSize = fileSize
    self.overview = overview
    self.runtimeInSeconds = runtimeInSeconds
    self.genres = genres
    self.tags = tags
  }
}

public enum JellyfinLayout {
  public enum Options: String {
    case grid, list
  }

  public enum SortBy: String {
    case recent, name, smart
  }
}
