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
    static let importer = ImportManager.shared
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

  public class func cleanAndReloadLibrary() {
    DataManager.cleanupStoreFile()

    let enumerator = FileManager.default.enumerator(
      at: DataManager.getProcessedFolderURL(),
      includingPropertiesForKeys: [.creationDateKey, .isDirectoryKey],
      options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants], errorHandler: { (url, error) -> Bool in
        print("directoryEnumerator error at \(url): ", error)
        return true
      })!
    var files = [URL]()
    for case let fileURL as URL in enumerator {
      files.append(fileURL)
    }

    guard let library = try? DataManager.getLibrary() ??
            Library.create(in: self.getContext()) else { return }

    saveContext()

    DataManager.setupDefaultTheme()

    _ = DataManager.insertItems(from: files, into: nil, library: library)

    saveContext()
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

    /**
     Notifies the ImportManager about the new file
     - Parameter origin: File original location
     */
    public class func processFile(at origin: URL) {
      self.importer.process(origin)
    }

    /**
     Find all the files in the documents folder and send notifications about their existence.
     */
    public class func notifyPendingFiles() {
        let documentsFolder = self.getDocumentsFolderURL()

        // Get reference of all the files located inside the folder
        guard let urls = self.getFiles(from: documentsFolder) else {
            return
        }

        for url in urls {
            self.processFile(at: url)
        }
    }

    public class func exists(_ book: Book) -> Bool {
        guard let fileURL = book.fileURL else { return false }

        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    // MARK: - Themes

  public class func setupDefaultTheme() {
    let userDefaults = UserDefaults(suiteName: Constants.ApplicationGroupIdentifier)

    // Migrate user defaults app icon
    if userDefaults?
        .string(forKey: Constants.UserDefaults.appIcon.rawValue) == nil {
      let storedIconId = UserDefaults.standard.string(forKey: Constants.UserDefaults.appIcon.rawValue)
      userDefaults?.set(storedIconId, forKey: Constants.UserDefaults.appIcon.rawValue)
    } else if let sharedAppIcon = userDefaults?
                .string(forKey: Constants.UserDefaults.appIcon.rawValue),
              let localAppIcon = UserDefaults.standard.string(forKey: Constants.UserDefaults.appIcon.rawValue),
              sharedAppIcon != localAppIcon {
      userDefaults?.set(localAppIcon, forKey: Constants.UserDefaults.appIcon.rawValue)
      UserDefaults.standard.removeObject(forKey: Constants.UserDefaults.appIcon.rawValue)
    }

    // Exclude Processed folder from phone backups
    var resourceValues = URLResourceValues()
    resourceValues.isExcludedFromBackup = true
    var processedFolderURL = self.getProcessedFolderURL()

    try? processedFolderURL.setResourceValues(resourceValues)

    // Set system theme as default
    if UserDefaults.standard.object(forKey: Constants.UserDefaults.systemThemeVariantEnabled.rawValue) == nil {
      UserDefaults.standard.set(true, forKey: Constants.UserDefaults.systemThemeVariantEnabled.rawValue)
    }

    guard let library = try? self.getLibrary(),
          library.currentTheme == nil else { return }

    library.currentTheme = self.getLocalThemes().first!

    self.saveContext()
  }

    public class func getLocalThemes() -> [Theme] {
        guard
            let themesFile = Bundle.main.url(forResource: "Themes", withExtension: "json"),
            let data = try? Data(contentsOf: themesFile, options: .mappedIfSafe),
            let jsonObject = try? JSONSerialization.jsonObject(with: data, options: .mutableLeaves),
            let themeParams = jsonObject as? [[String: Any]]
        else { return [] }

        var themes = [Theme]()

        for themeParam in themeParams {
            let request: NSFetchRequest<Theme> = Theme.fetchRequest()

            guard let predicate = Theme.searchPredicate(themeParam) else { continue }

            request.predicate = predicate

            var theme: Theme!

            if let storedThemes = try? self.getContext().fetch(request),
                let storedTheme = storedThemes.first {
                theme = storedTheme
                theme.locked = themeParam["locked"] as? Bool ?? false
            } else {
                theme = Theme(params: themeParam, context: self.getContext())
            }

            themes.append(theme)
        }

        return themes
    }

    public class func getExtractedThemes() -> [Theme] {
      let library = try? self.getLibrary()
      return library?.extractedThemes?.array as? [Theme] ?? []
    }

    public class func addExtractedTheme(_ theme: Theme) {
      guard let library = try? self.getLibrary() else { return }

      library.addToExtractedThemes(theme)
      self.saveContext()
    }

    public class func setCurrentTheme(_ theme: Theme) {
      guard let library = try? self.getLibrary() else { return }
      library.currentTheme = theme
      DataManager.saveContext()
    }
}
