//
//  AudiobookShelfLibraryLevelData.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/14/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import Foundation

enum AudiobookShelfLibraryLevelData: Equatable, Hashable {
  case topLevel(libraryName: String)
  case library(data: AudiobookShelfLibraryItem)
  case details(data: AudiobookShelfLibraryItem)
}
