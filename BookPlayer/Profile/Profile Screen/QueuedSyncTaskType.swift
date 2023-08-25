//
//  QueuedSyncTaskType.swift
//  BookPlayer
//
//  Created by gianni.carlo on 26/5/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import Foundation

enum QueuedSyncTaskType {
  case upload
  case update
  case move
  case delete
  case shallowDelete
  case setBookmark
  case deleteBookmark
  
  var imageName: String {
    switch self {
    case .upload:
      return "arrow.up.to.line"
    case .update:
      return "arrow.2.circlepath"
    case .move:
      return "arrow.forward"
    case .delete:
      return "xmark.bin.fill"
    case .shallowDelete:
      return "xmark.bin"
    case .setBookmark:
      return "bookmark"
    case .deleteBookmark:
      return "bookmark.slash"
    }
  }
}
