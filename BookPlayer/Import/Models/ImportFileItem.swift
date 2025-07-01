//
//  ImportFileItem.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 9/11/18.
//  Copyright © 2018 BookPlayer LLC. All rights reserved.
//

import Foundation

public class ImportFileItem: NSCopying, Comparable {
  public var fileURL: URL
  public var name: String
  public var subItems = 0

  public init(fileURL: URL) {
    self.fileURL = fileURL
    self.name = fileURL.lastPathComponent
  }

  public func copy(with zone: NSZone? = nil) -> Any {
    ImportFileItem(fileURL: fileURL)
  }
}

// MARK: - Comparable
extension ImportFileItem {
  public static func < (lhs: ImportFileItem, rhs: ImportFileItem) -> Bool {
    lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
  }
  
  public static func == (lhs: ImportFileItem, rhs: ImportFileItem) -> Bool {
    lhs.fileURL == rhs.fileURL
  }
}
