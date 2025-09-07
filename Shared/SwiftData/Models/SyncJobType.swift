//
//  SyncJobType.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 6/9/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import Foundation

public enum SyncJobType: String, CaseIterable, Codable {
  case upload
  case update
  case move
  case renameFolder
  case delete
  case shallowDelete
  case setBookmark
  case deleteBookmark
  case uploadArtwork
}
