//
//  ItemListSheet.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/10/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation

/// Represents all possible sheet types in ItemListView
enum ItemListSheet: Identifiable {
  case itemDetails(SimpleLibraryItem)
  case queuedTasks
  case jellyfin
  case foldersSelection
  
  var id: String {
    switch self {
    case .itemDetails(let item):
      return "itemDetails-\(item.id)"
    case .queuedTasks:
      return "queuedTasks"
    case .jellyfin:
      return "jellyfin"
    case .foldersSelection:
      return "foldersSelection"
    }
  }
}
