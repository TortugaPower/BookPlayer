//
//  FileItem.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 9/11/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import Foundation

public class FileItem: NSCopying {
  public var originalUrl: URL
  public var destinationFolder: URL
  public var subItems = 0

  public var processedUrl: URL {
    return self.destinationFolder.appendingPathComponent(self.originalUrl.lastPathComponent)
  }

  public init(originalUrl: URL, destinationFolder: URL) {
    self.originalUrl = originalUrl
    self.destinationFolder = destinationFolder
  }

  public func copy(with zone: NSZone? = nil) -> Any {
    return FileItem(originalUrl: self.originalUrl, destinationFolder: self.destinationFolder)
  }

  public func getOriginalName() -> String {
    return self.originalUrl.lastPathComponent
  }
}
