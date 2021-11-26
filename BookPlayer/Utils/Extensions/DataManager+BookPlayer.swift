//
//  DataManager+BookPlayer.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/23/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import AVFoundation
import BookPlayerKit
import CoreData
import Foundation
import IDZSwiftCommonCrypto
import UIKit

extension DataManager {
  static let queue = OperationQueue()

  // MARK: - Operations

  public class func start(_ operation: Operation) {
    self.queue.addOperation(operation)
  }

  // MARK: - File processing

  /**
   Get url of files in a directory

   - Parameter folder: The folder from which to get all the files urls
   - Returns: Array of file-only `URL`, directories are excluded. It returns `nil` if the folder is empty.
   */
  public class func getFiles(from folder: URL) -> [URL]? {
    // Get reference of all the files located inside the Documents folder
    guard let urls = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: .skipsSubdirectoryDescendants) else {
      return nil
    }

    return filterFiles(urls)
  }

  /**
   Filter out Processed and Inbox folders from file URLs.
   */
  private class func filterFiles(_ urls: [URL]) -> [URL] {
    return urls.filter {
      $0.lastPathComponent != DataManager.processedFolderName
      && $0.lastPathComponent != DataManager.inboxFolderName
    }
  }

  public class func importData(from item: ImportableItem) {
    let filename = item.suggestedName ?? "\(Date().timeIntervalSince1970).\(item.fileExtension)"

    let destinationURL = self.getDocumentsFolderURL()
      .appendingPathComponent(filename)

    do {
      try item.data.write(to: destinationURL)
    } catch {
      print("Fail to move dropped file to the Documents directory: \(error.localizedDescription)")
    }
  }
}
