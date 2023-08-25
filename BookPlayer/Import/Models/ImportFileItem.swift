//
//  ImportFileItem.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 9/11/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import Foundation

public class ImportFileItem: NSCopying {
  public var fileUrl: URL
  public var subItems = 0
  
  public init(fileUrl: URL) {
    self.fileUrl = fileUrl
  }
  
  public func copy(with zone: NSZone? = nil) -> Any {
    return ImportFileItem(fileUrl: self.fileUrl)
  }
  
  public func getFileName() -> String {
    return self.fileUrl.lastPathComponent
  }
}
