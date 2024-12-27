//
//  SortType.swift
//  BookPlayer
//
//  Created by gianni.carlo on 21/10/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import CoreData
import Foundation

public enum SortType {
  case metadataTitle
  case fileName
  case mostRecent
  case reverseOrder

  func fetchProperties() -> [String] {
    var properties = [
      #keyPath(LibraryItem.relativePath),
      #keyPath(LibraryItem.orderRank)
    ]

    switch self {
    case .metadataTitle:
      properties.append(#keyPath(LibraryItem.title))
    case .fileName:
      properties.append(#keyPath(LibraryItem.originalFileName))
    case .mostRecent:
      properties.append(#keyPath(LibraryItem.lastPlayDate))
    case .reverseOrder:
      break
    }
    return properties
  }

  func sortItems(_ items: [LibraryItem]) -> [LibraryItem] {
    switch self {
    case .fileName:
      return items.sorted { a, b in
        a.originalFileName.localizedStandardCompare(b.originalFileName)
        == ComparisonResult.orderedAscending
      }
    case .metadataTitle:
      return items.sorted { a, b in
        a.title.localizedStandardCompare(b.title)
        == ComparisonResult.orderedAscending
      }
    case .mostRecent:
      let distantPast = Date.distantPast
      return items.sorted { a, b in
        let t1 = a.lastPlayDate ?? distantPast
        let t2 = b.lastPlayDate ?? distantPast
        return t1 > t2
      }
    case .reverseOrder:
      return items.reversed()
    }
  }
}
