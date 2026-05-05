//
//  LibraryItemRef.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 6/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

/// A lightweight reference to a library item or location.
///
/// Used in two senses:
/// - **Item reference**: identifies an existing item (used when moving or referring to a specific book/folder).
/// - **Location**: identifies a folder; `nil` (`LibraryItemRef?`) represents the library root.
public struct LibraryItemRef: Equatable, Hashable {
  public var relativePath: String
  public var uuid: String

  public init(relativePath: String, uuid: String) {
    self.relativePath = relativePath
    self.uuid = uuid
  }
}
