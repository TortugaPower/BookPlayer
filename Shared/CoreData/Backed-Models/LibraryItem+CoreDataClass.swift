//
//  LibraryItem+CoreDataClass.swift
//  BookPlayerKit
//
//  Created by Gianni Carlo on 4/23/19.
//  Copyright © 2019 BookPlayer LLC. All rights reserved.
//
//

import CoreData
import Foundation
import UIKit

@objc(LibraryItem)
public class LibraryItem: NSManagedObject, Codable {
  public var fileURL: URL? {
    guard self.relativePath != nil else { return nil }

    return DataManager.getProcessedFolderURL().appendingPathComponent(self.relativePath)
  }

  public var lastPathComponent: String? {
    guard self.relativePath != nil,
          let lastComponent = self.relativePath.split(separator: "/").last else { return nil }

    return String(lastComponent)
  }

  public func getLibrary() -> Library? {
    if let parentFolder = self.folder {
      return parentFolder.getLibrary()
    }

    return self.library
  }

  public func encode(to encoder: Encoder) throws {
    fatalError("LibraryItem is an abstract class, override this function in the subclass")
  }

  public required convenience init(from decoder: Decoder) throws {
    fatalError("LibraryItem is an abstract class, override this function in the subclass")
  }
}
