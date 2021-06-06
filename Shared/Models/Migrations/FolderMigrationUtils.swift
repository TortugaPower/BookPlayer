//
//  FolderMigrationUtils.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 3/6/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import CoreData
import Foundation

extension DataMigrationManager {
    func migrateBooks() {
        let fetch: NSFetchRequest<Book> = Book.fetchRequest()
        let context = self.stack.managedContext

        guard let books = try? context.fetch(fetch) else { return }

        let processedFolder = DataManager.getProcessedFolderURL()
        var index = 0

        for book in books {
            guard let identifier = book.identifier,
                  let originalFilename = book.originalFileName else { continue }

            let currentURL = processedFolder.appendingPathComponent(identifier)
            var destinationURL = processedFolder

            if let folder = book.folder {
                destinationURL = destinationURL.appendingPathComponent(folder.relativePath)
            }

            destinationURL = destinationURL.appendingPathComponent(originalFilename)

            // Just in case there's already a file with that name
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                destinationURL = currentURL.deletingLastPathComponent().appendingPathComponent("\(index)_\(originalFilename)")
            }

            do {
                try FileManager.default.moveItem(at: currentURL, to: destinationURL)
                book.relativePath = destinationURL.relativePath(to: processedFolder)
            } catch {
                print(error.localizedDescription)
            }

            index += 1
        }

        do {
            try context.save()
        } catch let error as NSError {
            fatalError("Unresolved error \(error), \(error.userInfo)")
        }
    }

    func migrateFolderHierarchy() {
        let fetch: NSFetchRequest<Folder> = Folder.fetchRequest()
        let context = self.stack.managedContext

        guard let folders = try? context.fetch(fetch) else { return }

        let processedFolder = DataManager.getProcessedFolderURL()
        var index = 0

        for folder in folders {
            guard let folderTitle = folder.title else { continue }

            var destinationURL = processedFolder.appendingPathComponent(folderTitle)

            // Just in case there's already a file with that name
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                destinationURL = destinationURL.deletingLastPathComponent().appendingPathComponent("\(index)_\(folderTitle)")
            }

            do {
                try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
                folder.relativePath = destinationURL.lastPathComponent
            } catch {
                print(error.localizedDescription)
            }

            index += 1
        }

        do {
            try context.save()
        } catch let error as NSError {
            fatalError("Unresolved error \(error), \(error.userInfo)")
        }
    }
}
