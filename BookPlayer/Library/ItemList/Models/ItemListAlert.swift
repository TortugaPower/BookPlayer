//
//  ItemListAlert.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/10/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation

/// Represents all possible alert types in ItemListView
enum ItemListAlert: Identifiable, Equatable {
  case queuedTasks
  case importCompletion(ImportOperationState.AlertParameters)
  case moveOptions
  case createFolder(type: SimpleItemType, placeholder: String)
  case delete
  case cancelDownload(SimpleLibraryItem)
  case warningOffload(SimpleLibraryItem)
  case downloadURL(String)
  
  var id: String {
    switch self {
    case .queuedTasks:
      return "queuedTasks"
    case .importCompletion:
      return "importCompletion"
    case .moveOptions:
      return "moveOptions"
    case .createFolder:
      return "createFolder"
    case .delete:
      return "delete"
    case .cancelDownload(let item):
      return "cancelDownload-\(item.id)"
    case .warningOffload(let item):
      return "warningOffload-\(item.id)"
    case .downloadURL:
      return "downloadURL"
    }
  }
  
  // Equatable conformance
  static func == (lhs: ItemListAlert, rhs: ItemListAlert) -> Bool {
    lhs.id == rhs.id
  }
}
