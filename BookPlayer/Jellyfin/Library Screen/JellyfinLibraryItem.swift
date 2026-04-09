//
//  JellyfinLibraryItem.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-10-26.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Foundation
import JellyfinAPI

struct JellyfinLibraryItem: IntegrationLibraryItemProtocol {
  enum Kind {
    case userView
    case folder
    case audiobook
    case author
    case narrator
  }

  let id: String
  let name: String
  let kind: Kind

  let blurHash: String?
  let imageAspectRatio: Double?

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
  init(id: String, name: String, kind: Kind) {
    self.init(id: id, name: name, kind: kind, blurHash: nil, imageAspectRatio: nil)
  }
}

extension JellyfinLibraryItem {
  init?(apiItem: BaseItemDto) {
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

    self.init(id: id, name: name, kind: kind, blurHash: blurHash, imageAspectRatio: apiItem.primaryImageAspectRatio)
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
