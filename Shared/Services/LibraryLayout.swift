//
//  LibraryLayout.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 14/10/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

/// How the Library tab lays out a folder's items. Synced across devices under
/// `Constants.UserDefaults.libraryLayout`, by its raw value
public enum LibraryLayout: String, CaseIterable, Sendable {
  /// Rows: artwork beside the title, author and duration
  case list
  /// Cards: the cover, then the duration, title and author
  case grid
  /// Covers only, more to a row
  case covers
}
