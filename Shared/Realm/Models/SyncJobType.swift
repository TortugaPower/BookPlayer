//
//  SyncJobType.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 26/2/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Foundation
import RealmSwift

public enum SyncJobType: String, CaseIterable, Codable, PersistableEnum {
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
