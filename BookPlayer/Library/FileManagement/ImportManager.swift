//
//  ImportManager.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 9/10/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import Foundation
import BookPlayerKit

/**
 Handles the creation of ImportOperation objects.
 It waits a specified time wherein new files may be added before the operation is created
 */
class ImportManager: NSObject {
    static let shared = ImportManager()

    private let timeout = 2.0
    private var timer: Timer?
    private var files = [FileItem]()
    private let processedFolderName = "Processed"

    // MARK: - Folder URLs
    func getDocumentsFolderURL() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    func getProcessedFolderURL() -> URL {
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

    func process(_ fileUrl: URL) {
        let destinationFolder = self.getProcessedFolderURL()

        guard !self.files.contains(where: { $0.originalUrl == fileUrl }) else { return }

        self.setupTimer()

        let file = FileItem(originalUrl: fileUrl, processedUrl: nil, destinationFolder: destinationFolder)
        self.files.append(file)

        NotificationCenter.default.post(name: .newFileUrl, object: self, userInfo: nil)
    }

    private func setupTimer() {
        self.timer?.invalidate()
        self.timer = Timer(timeInterval: self.timeout, target: self, selector: #selector(self.createOperation), userInfo: nil, repeats: false)
        RunLoop.main.add(self.timer!, forMode: RunLoopMode.commonModes)
    }

    @objc private func createOperation() {
        guard !self.files.isEmpty else { return }

        let operation = ImportOperation(files: self.files)

        self.files = []

        NotificationCenter.default.post(name: .importOperation, object: self, userInfo: ["operation": operation])
    }

    // MARK: - File processing

    /**
     Remove file protection for folder so that when the app is on the background and the iPhone is locked, autoplay still works
     */
    func makeFilesPublic() {
        let processedFolder = self.getProcessedFolderURL()

        guard let files = self.getFiles(from: processedFolder) else { return }

        for file in files {
            self.makeFilePublic(file as NSURL)
        }
    }

    /**
     Remove file protection for one file
     */
    func makeFilePublic(_ file: NSURL) {
        try? file.setResourceValue(URLFileProtection.completeUntilFirstUserAuthentication, forKey: .fileProtectionKey)
    }

    /**
     Get url of files in a directory

     - Parameter folder: The folder from which to get all the files urls
     - Returns: Array of file-only `URL`, directories are excluded. It returns `nil` if the folder is empty.
     */
    func getFiles(from folder: URL) -> [URL]? {
        // Get reference of all the files located inside the Documents folder
        guard let urls = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: .skipsSubdirectoryDescendants) else {
            return nil
        }

        return filterFiles(urls)
    }

    /**
     Filter out folders from file URLs.
     */
    private func filterFiles(_ urls: [URL]) -> [URL] {
        return urls.filter({ !$0.hasDirectoryPath })
    }

    /**
     Find all the files in the documents folder and send notifications about their existence.
     */
    func notifyPendingFiles() {
        let documentsFolder = self.getDocumentsFolderURL()

        // Get reference of all the files located inside the folder
        guard let urls = self.getFiles(from: documentsFolder) else {
            return
        }

        for url in urls {
            self.process(url)
        }
    }

    // MARK: - Files
    /**
     Creates a book for each URL and adds it to the specified playlist. If no playlist is specified, it will be added to the library.

     A book can't be in two places at once, so if it already existed, it will be removed from the original playlist or library, and it will be added to the new one.

     - Parameter files: `Book`s will be created for each element in this array
     - Parameter playlist: `Playlist` to which the created `Book` will be added
     - Parameter library: `Library` to which the created `Book` will be added if the parameter `playlist` is nil
     - Parameter completion: Closure fired after processing all the urls.
     */
    func insertBooks(from files: [FileItem], into playlist: Playlist?, or library: Library, completion:@escaping () -> Void) {
        let context = DataManager.getContext()

        for file in files {
            // TODO: do something about unprocessed URLs
            guard let url = file.processedUrl else { continue }

            // Check if book exists in the library
            guard  let item = library.getItem(with: url) else {
                let book = Book(from: file, context: context)

                if let playlist = playlist {
                    playlist.addToBooks(book)
                } else {
                    library.addToItems(book)
                }

                continue
            }

            guard let storedPlaylist = item as? Playlist,
                let storedBook = storedPlaylist.getBook(with: url) else {
                    // swiftlint:disable force_cast
                    // Handle if item is a book
                    let storedBook = item as! Book

                    if let playlist = playlist {
                        library.removeFromItems(storedBook)
                        playlist.addToBooks(storedBook)
                    }

                    continue
            }

            // Handle if book already exists in the library
            storedPlaylist.removeFromBooks(storedBook)

            if let playlist = playlist {
                playlist.addToBooks(storedBook)
            } else {
                library.addToItems(storedBook)
            }

        }

        DataManager.saveContext()

        DispatchQueue.main.async {
            completion()
        }
    }

    /**
     Creates a book for each URL and adds it to the library. A book can't be in two places at once, so it will be removed if it already existed in a playlist.

     - Parameter bookUrls: `Book`s will be created for each element in this array
     - Parameter library: `Library` to which the created `Book` will be added
     - Parameter completion: Closure fired after processing all the urls.
     */
    func insertBooks(from files: [FileItem], into library: Library, completion:@escaping () -> Void) {
        self.insertBooks(from: files, into: nil, or: library, completion: completion)
    }

    /**
     Creates a book for each URL and adds it to the specified playlist. A book can't be in two places at once, so it will be removed from the library if it already existed.

     - Parameter bookUrls: `Book`s will be created for each element in this array
     - Parameter playlist: `Playlist` to which the created `Book` will be added
     - Parameter completion: Closure fired after processing all the urls.
     */
    func insertBooks(from files: [FileItem], into playlist: Playlist, completion:@escaping () -> Void) {
        self.insertBooks(from: files, into: playlist, or: playlist.library!, completion: completion)
    }

    func createPlaylist(title: String, books: [Book]) -> Playlist {
        return Playlist(title: title, books: books, context: DataManager.getContext())
    }

    func createBook(from file: FileItem) -> Book {
        return Book(from: file, context: DataManager.getContext())
    }

    func exists(_ book: Book) -> Bool {
        return FileManager.default.fileExists(atPath: book.fileURL.path)
    }
}
