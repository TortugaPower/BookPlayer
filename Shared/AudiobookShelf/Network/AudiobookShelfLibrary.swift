//
//  AudiobookShelfLibrary.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 14/11/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import Foundation

public struct AudiobookShelfLibrary: Codable, Identifiable {
  public let id: String
  public let name: String
  public let folders: [Folder]
  public let displayOrder: Int
  public let icon: String
  public let mediaType: String  // "book" or "podcast"
  public let provider: String
  
  public struct Folder: Codable {
    let id: String
    let fullPath: String
    let libraryId: String
  }
}

public struct AudiobookShelfLibrariesResponse: Codable {
  let libraries: [AudiobookShelfLibrary]
}
