//
//  SyncStatus.swift
//  BookPlayer
//
//  Created by gianni.carlo on 3/8/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation

/// Pending sync status
@objc public enum SyncStatus: Int16 {
       /// For local items
  case metadataUpload, fileUpload,
       /// For remote items that were synced
       contentsDownload, parentFolder,
       /// ongoing states
       progress, synced
}
