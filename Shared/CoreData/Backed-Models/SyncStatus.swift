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
       /// Only the metadata is stored locally
  case metadata,
       /// Downloading file
       progress,
       /// We have both the metadata and file stored locally
       synced
}
