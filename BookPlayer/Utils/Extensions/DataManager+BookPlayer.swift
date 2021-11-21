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

    class func isProcessingFiles() -> Bool {
        return !self.queue.operations.isEmpty
    }

    class func countOfProcessingFiles() -> Int {
        var count = 0
        // swiftlint:disable force_cast
        for operation in self.queue.operations as! [ImportOperation] {
            count += operation.files.count
        }
        // swiftlint:enable force_cast
        return count
    }

    // MARK: - File processing

    /**
     Remove file protection for processed folder so that when the app is on the background and the iPhone is locked, autoplay still works
     */
    public class func makeFilesPublic() {
        let processedFolder = self.getProcessedFolderURL()

        guard let files = self.getFiles(from: processedFolder) else { return }

        for file in files {
            self.makeFilePublic(file as NSURL)
        }
    }

    /**
     Remove file protection for one file
     */
    class func makeFilePublic(_ file: NSURL) {
        try? file.setResourceValue(URLFileProtection.none, forKey: .fileProtectionKey)
    }

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

    public class func exists(_ book: Book) -> Bool {
        guard let fileURL = book.fileURL else { return false }

        return FileManager.default.fileExists(atPath: fileURL.path)
    }

  // MARK: - Themes
  public func hasThemesLoaded() -> Bool {
    let fetchRequest: NSFetchRequest<Theme> = Theme.fetchRequest()
    fetchRequest.fetchLimit = 1

    let themes = (try? self.getContext().fetch(fetchRequest)) ?? []

    return !themes.isEmpty
  }

  public func loadLocalThemes() {
    guard
      let themesFile = Bundle.main.url(forResource: "Themes", withExtension: "json"),
      let data = try? Data(contentsOf: themesFile, options: .mappedIfSafe),
      let jsonObject = try? JSONSerialization.jsonObject(with: data, options: .mutableLeaves),
      let themeParams = jsonObject as? [[String: Any]]
    else { return }

    for themeParam in themeParams {
      _ = Theme(params: themeParam, context: self.getContext())
    }

    self.saveContext()
  }

  public class func getLocalThemes() -> [Theme] {
    guard
      let themesFile = Bundle.main.url(forResource: "Themes", withExtension: "json"),
      let data = try? Data(contentsOf: themesFile, options: .mappedIfSafe),
      let response = try? JSONDecoder().decode([Theme].self, from: data)
    else { return [] }

    return response
  }

  public func setCurrentTheme(_ theme: Theme, for library: Library) {
    library.currentTheme = theme
    self.saveContext()
  }
}
