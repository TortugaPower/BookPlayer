//
//  DataManager.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/30/17.
//  Copyright © 2017 Tortuga Power. All rights reserved.
//

import AVFoundation
import CoreData
import Foundation
import IDZSwiftCommonCrypto
import UIKit

class DataManager {
    static let processedFolderName = "Processed"

    static let importer = ImportManager()
    static let queue = OperationQueue()

    static let smallTip: ProductIdentifier = "com.tortugapower.audiobookplayer.3dollars"
    static let midTip: ProductIdentifier = "com.tortugapower.audiobookplayer.fivedollars"
    static let largeTip: ProductIdentifier = "com.tortugapower.audiobookplayer.tendollars"
    static let store = IAPHelper(productIds: Set([smallTip, midTip, largeTip]))

    // MARK: - Folder URLs

    class func getDocumentsFolderURL() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    class func getProcessedFolderURL() -> URL {
        let documentsURL = self.getDocumentsFolderURL()

        let processedFolderURL = documentsURL.appendingPathComponent(self.processedFolderName)

        if !FileManager.default.fileExists(atPath: processedFolderURL.path) {
            do {
                try FileManager.default.createDirectory(at: processedFolderURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                fatalError("Couldn't create Processed folder")
            }
        }

        return processedFolderURL
    }

    internal static var storeUrl: URL {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.ApplicationGroupIdentifier)!.appendingPathComponent("BookPlayer.sqlite")
    }

    // MARK: - Operations

    class func start(_ operation: Operation) {
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

    // MARK: - Core Data stack

    class func migrateStack() throws {
        let name = "BookPlayer"
        let container = NSPersistentContainer(name: name)
        let psc = container.persistentStoreCoordinator

        let oldStoreUrl = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).last!
            .appendingPathComponent("\(name).sqlite")

        let options = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true
        ]

        guard let oldStore = try? psc.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: oldStoreUrl, options: options) else {
            // couldn't load old store
            return
        }

        try psc.migratePersistentStore(oldStore, to: self.storeUrl, options: nil, withType: NSSQLiteStoreType)
    }

    // MARK: - File processing

    /**
     Remove file protection for processed folder so that when the app is on the background and the iPhone is locked, autoplay still works
     */
    class func makeFilesPublic() {
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
    class func getFiles(from folder: URL) -> [URL]? {
        // Get reference of all the files located inside the Documents folder
        guard let urls = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: .skipsSubdirectoryDescendants) else {
            return nil
        }

        return filterFiles(urls)
    }

    /**
     Filter out folders from file URLs.
     */
    private class func filterFiles(_ urls: [URL]) -> [URL] {
        return urls.filter({ !$0.hasDirectoryPath })
    }

    /**
     Notifies the ImportManager about the new file
     - Parameter origin: File original location
     */
    class func processFile(at origin: URL) {
        self.processFile(at: origin, destinationFolder: self.getProcessedFolderURL())
    }

    /**
     Notifies the ImportManager about the new file
     - Parameter origin: File original location
     - Parameter destinationFolder: File final location
     */
    class func processFile(at origin: URL, destinationFolder: URL) {
        self.importer.process(origin, destinationFolder: destinationFolder)
    }

    /**
     Find all the files in the documents folder and send notifications about their existence.
     */
    class func notifyPendingFiles() {
        let documentsFolder = self.getDocumentsFolderURL()

        // Get reference of all the files located inside the folder
        guard let urls = self.getFiles(from: documentsFolder) else {
            return
        }

        let processedFolder = self.getProcessedFolderURL()

        for url in urls {
            self.processFile(at: url, destinationFolder: processedFolder)
        }
    }

    class func setupDefaultTheme() {
        let library = self.getLibrary()

        guard library.currentTheme == nil else { return }

        library.currentTheme = self.getLocalThemes().first!

        // prior book artwork colors didn't have a title
        if let books = self.getBooks() {
            for book in books {
                book.artworkColors.title = book.title
            }
        }

        self.saveContext()
    }

    class func getLocalThemes() -> [Theme] {
        guard
            let themesFile = Bundle.main.url(forResource: "Themes", withExtension: "json"),
            let data = try? Data(contentsOf: themesFile, options: .mappedIfSafe),
            let jsonObject = try? JSONSerialization.jsonObject(with: data, options: .mutableLeaves),
            let themeParams = jsonObject as? [[String: String]]
        else { return [] }

        var themes = [Theme]()

        for themeParam in themeParams {
            let request: NSFetchRequest<Theme> = Theme.fetchRequest()

            guard let predicate = Theme.searchPredicate(themeParam) else { continue }

            request.predicate = predicate

            var theme: Theme!

            if let storedThemes = try? self.persistentContainer.viewContext.fetch(request),
                let storedTheme = storedThemes.first {
                theme = storedTheme
            } else {
                theme = Theme(params: themeParam, context: self.persistentContainer.viewContext)
            }

            themes.append(theme)
        }

        return themes
    }

    class func getExtractedThemes() -> [Theme] {
        let library = self.getLibrary()
        return library.extractedThemes?.array as? [Theme] ?? []
    }

    class func addExtractedTheme(_ theme: Theme) {
        let library = self.getLibrary()
        library.addToExtractedThemes(theme)
        self.saveContext()
    }

    class func setCurrentTheme(_ theme: Theme) {
        let library = self.getLibrary()
        library.currentTheme = theme
        DataManager.saveContext()
    }

    class func getIcons() -> [Icon] {
        guard
            let iconsFile = Bundle.main.url(forResource: "Icons", withExtension: "json"),
            let data = try? Data(contentsOf: iconsFile, options: .mappedIfSafe),
            let icons = try? JSONDecoder().decode([Icon].self, from: data)
        else { return [] }

        return icons
    }

    class func exists(_ book: Book) -> Bool {
        return FileManager.default.fileExists(atPath: book.fileURL.path)
    }
}
