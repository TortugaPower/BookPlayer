//
//  SimpleItemType.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 17/9/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import Foundation

public enum SimpleItemType: Int16, Decodable {
  case folder, bound, book

  var itemType: ItemType {
    switch self {
    case .book:
      return .book
    case .bound:
      return .bound
    case .folder:
      return .folder
    }
  }
}
