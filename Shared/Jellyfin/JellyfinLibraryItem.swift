//
//  JellyfinLibraryItem.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-10-26.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Foundation
import JellyfinAPI

public struct JellyfinLibraryItem: IntegrationLibraryItemProtocol {
  public enum Kind {
    case userView
    case folder
    case audiobook
    case author
    case narrator
  }

  public let id: String
  public let name: String
  public let kind: Kind
  
  public let durationSeconds: Int64?
  public let currentSeconds: Int64?
  public let isFinished: Bool?
  public let lastPlayedDate: Date?
  public let blurHash: String?
  public let imageAspectRatio: Double?
  public let details: JellyfinAudiobookDetailsData?

  var isDownloadable: Bool {
    kind == .audiobook
  }

  var isNavigable: Bool {
    !isDownloadable
  }

  var displayName: String { name }

  var placeholderImageName: String {
    switch kind {
    case .audiobook: "waveform"
    case .userView, .folder: "folder"
    case .author: "person"
    case .narrator: "mic"
    }
  }
}

extension JellyfinLibraryItem {
  public init(id: String, name: String, kind: Kind) {
    self.init(
      id: id,
      name: name,
      kind: kind,
      durationSeconds: nil,
      currentSeconds: nil,
      isFinished: false,
      lastPlayedDate: nil,
      blurHash: nil,
      imageAspectRatio: nil,
      details: nil
    )
  }
}

extension JellyfinLibraryItem {
  public init?(apiItem: BaseItemDto) {
    let kind: JellyfinLibraryItem.Kind? = switch apiItem.type {
    case .userView, .collectionFolder: .userView
    case .folder: .folder
    case .audioBook: .audiobook
    default: nil
    }
    
    guard let id = apiItem.id, let kind else {
      return nil
    }
    let name = apiItem.name ?? id
    let blurHash = apiItem.imageBlurHashes?.primary?.first?.value
    
    var myDetails: JellyfinAudiobookDetailsData? = nil
    
    if let artist = apiItem.albumArtist,
      let filePath = apiItem.mediaSources?.first?.path ?? apiItem.path,
      let fileSize = apiItem.mediaSources?.first?.size,
       let runtimeInSeconds = (apiItem.runTimeTicks != nil) ? TimeInterval(apiItem.runTimeTicks!) / 10000000.0 : nil {
      myDetails = JellyfinAudiobookDetailsData(
        artist: artist,
        filePath: filePath,
        fileSize: fileSize,
        overview: apiItem.overview,
        runtimeInSeconds: runtimeInSeconds,
        genres: apiItem.genres,
        tags: apiItem.tags
      )
    }
    
    self.init(
      id: id,
      name: name,
      kind: kind,
      durationSeconds: Int64((apiItem.runTimeTicks ?? 0) / 10000000),
      currentSeconds: Int64((apiItem.userData?.playbackPositionTicks ?? 0) / 10000000),
      isFinished: apiItem.userData?.isPlayed,
      lastPlayedDate: apiItem.userData?.lastPlayedDate,
      blurHash: blurHash,
      imageAspectRatio: apiItem.primaryImageAspectRatio,
      details: myDetails
    )
  }

  /// Create an author item from an AlbumArtists API response
  init?(authorApiItem: BaseItemDto) {
    guard let id = authorApiItem.id else { return nil }
    let name = authorApiItem.name ?? id
    let blurHash = authorApiItem.imageBlurHashes?.primary?.first?.value
    self.init(id: id, name: name, kind: .author, blurHash: blurHash, imageAspectRatio: authorApiItem.primaryImageAspectRatio)
  }

  /// Create a narrator item from a Persons API response
  init?(narratorApiItem: BaseItemDto) {
    guard let id = narratorApiItem.id else { return nil }
    let name = narratorApiItem.name ?? id
    let blurHash = narratorApiItem.imageBlurHashes?.primary?.first?.value
    self.init(id: id, name: name, kind: .narrator, blurHash: blurHash, imageAspectRatio: narratorApiItem.primaryImageAspectRatio)
  }
}
