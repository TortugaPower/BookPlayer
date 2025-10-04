//
//  FolderCreationInput.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/10/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation

/// Holds folder creation form data
struct FolderCreationInput {
  var name: String = ""
  var placeholder: String = ""
  var type: SimpleItemType = .folder
  
  mutating func reset() {
    name = ""
    placeholder = ""
    type = .folder
  }
  
  mutating func prepareForBound(title: String? = nil, placeholder suggestedPlaceholder: String = "") {
    name = title ?? ""
    placeholder = title ?? suggestedPlaceholder
    type = .bound
  }
  
  mutating func prepareForFolder(placeholder suggestedPlaceholder: String = "") {
    name = ""
    placeholder = suggestedPlaceholder
    type = .folder
  }
}
