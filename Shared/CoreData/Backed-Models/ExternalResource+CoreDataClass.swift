//
//  ExternalResource+CoreDataClass.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 13/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation
import CoreData
import SwiftUI

extension ExternalResource {
  public enum SyncStatus: String, Codable {
    case notSynced = "not_synced"
    case syncing = "syncing"
    case synced = "synced"
  }
  
  public enum ProviderName: String, Codable {
    case jellyfin
    case hardcover
    case audiobookshelf
    
    public var icon: ImageResource {
      switch self {
      case .jellyfin:
        return .jellyfinIcon
      case .hardcover:
        return .plusImageAppIcons
      case .audiobookshelf:
        return .audiobookshelfIcon
      }
    }
  }
}
