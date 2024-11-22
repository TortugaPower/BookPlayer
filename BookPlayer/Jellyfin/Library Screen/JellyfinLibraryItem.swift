//
//  JellyfinLibraryItem.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-10-26.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import Foundation
import JellyfinAPI

struct JellyfinLibraryItem: Identifiable, Hashable {
  enum Kind {
    case userView
    case folder
    case audiobook
  }

  let id: String
  let name: String
  let kind: Kind

  let blurHash: String?
  let imageAspectRatio: Double?
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
}
