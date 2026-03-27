//
//  JellyfinLibraryItem.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-10-26.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Foundation
import JellyfinAPI

public struct JellyfinLibraryItem: Identifiable, Hashable {
  public enum Kind {
    case userView
    case folder
    case audiobook
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
      imageAspectRatio: nil
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
    
    self.init(
      id: id,
      name: name,
      kind: kind,
      durationSeconds: Int64((apiItem.runTimeTicks ?? 0) / 10000000),
      currentSeconds: Int64((apiItem.userData?.playbackPositionTicks ?? 0) / 10000000),
      isFinished: apiItem.userData?.isPlayed,
      lastPlayedDate: apiItem.userData?.lastPlayedDate,
      blurHash: blurHash,
      imageAspectRatio: apiItem.primaryImageAspectRatio
    )
  }
}
