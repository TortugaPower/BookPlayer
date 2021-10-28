//
//  LibraryItem+CoreDataClass.swift
//  BookPlayerKit
//
//  Created by Gianni Carlo on 4/23/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
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

    public func getBookToPlay() -> Book? {
        return nil
    }

    // Represents sum of current time
    public var progress: Double {
        return 0
    }

    // Percentage represented from 0 to 1
    public var progressPercentage: Double {
        return 1.0
    }

    public func info() -> String { return "" }

    public func jumpToStart() {}

    public func markAsFinished(_ flag: Bool) {}

    public func setCurrentTime(_ time: Double) {}

  public func index(for item: LibraryItem) -> Int? { return nil }

  public func getFolder(matching relativePath: String) -> Folder? { return nil }

    public func getItem(with relativePath: String) -> LibraryItem? { return nil }

    public func encode(to encoder: Encoder) throws {
        fatalError("LibraryItem is an abstract class, override this function in the subclass")
    }

    public required convenience init(from decoder: Decoder) throws {
        fatalError("LibraryItem is an abstract class, override this function in the subclass")
    }
}
