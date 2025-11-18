//
//  AudiobookShelfLibrary.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 14/11/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import Foundation

struct AudiobookShelfLibrary: Codable, Identifiable {
  let id: String
  let name: String
  let folders: [Folder]
  let displayOrder: Int
  let icon: String
  let mediaType: String  // "book" or "podcast"
  let provider: String
  
  struct Folder: Codable {
    let id: String
    let fullPath: String
    let libraryId: String
  }
}

struct AudiobookShelfLibrariesResponse: Codable {
  let libraries: [AudiobookShelfLibrary]
}
