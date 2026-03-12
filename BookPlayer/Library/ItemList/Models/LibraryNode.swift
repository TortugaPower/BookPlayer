//
//  LibraryNode.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import Foundation

enum LibraryNode: Equatable, Hashable {
  case root
  case book(title: String, relativePath: String, uuid: String)
  case folder(title: String, relativePath: String, uuid: String)

  var title: String {
    switch self {
    case .root: "library_title".localized
    case .book(let title, _, _), .folder(let title, _, _): title
    }
  }

  var folderRelativePath: String? {
    switch self {
    case .root, .book: nil
    case .folder(_, let relativePath, _): relativePath
    }
  }
  
  var uuid: String {
    switch self {
    case .root: ""
    case .folder(_, _, let uuid), .book(_, _, let uuid): uuid
    }
  }
}
