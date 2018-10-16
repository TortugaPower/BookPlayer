//
//  CarPlayManager.swift
//  BookPlayer
//
//  Created by Florian Pichler on 27.09.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit
import MediaPlayer

enum BookPlayerError: Error {
    case UnableToLoadBooks(String)
}

let playlistItemsOffset: Int = 1

class CarPlayManager: NSObject, MPPlayableContentDataSource, MPPlayableContentDelegate {
    static let shared = CarPlayManager()

    var library: Library!

    private override init() {
        self.library = DataManager.getLibrary()
    }

    func reload() {
        MPPlayableContentManager.shared().reloadData()
    }

    // MARK: - MPPlayableContentDataSource

    func numberOfChildItems(at indexPath: IndexPath) -> Int {
        if indexPath.indices.count == 0 {
            return self.library.items?.count ?? 0
        }

        guard let playlist = self.library.getItem(at: indexPath[0]) as? Playlist, let count = playlist.books?.count else {
            return 0
        }

        return count + playlistItemsOffset
    }

    func beginLoadingChildItems(at indexPath: IndexPath, completionHandler: @escaping (Error?) -> Void) {
        completionHandler(nil)
    }

    func childItemsDisplayPlaybackProgress(at indexPath: IndexPath) -> Bool {
        if indexPath.count == 2 && indexPath[1] == 0 {
            return false
        }

        return true
    }

    func contentItem(at indexPath: IndexPath) -> MPContentItem? {
        if indexPath.count == 2 && indexPath[1] == 0 {
            let contentItem = MPContentItem(identifier: UUID().uuidString)

            contentItem.title = "Continue with first unfinished file"
            contentItem.isPlayable = false

            return contentItem
        }

        guard let libraryItem = self.getLibraryItem(at: indexPath) else {
            return nil
        }

        let contentItem = MPContentItem(identifier: libraryItem.identifier)

        contentItem.title = libraryItem.title
        contentItem.playbackProgress = libraryItem.isCompleted ? 1.0 : Float(libraryItem.currentTime / libraryItem.duration)

        if let book = libraryItem as? Book {
            contentItem.subtitle = book.author ?? ""
            contentItem.isPlayable = true
        }

        if let playlist = libraryItem as? Playlist {
            contentItem.isContainer = true
            contentItem.subtitle = "No files"

            if let count = playlist.books?.count, count > 0 {
                contentItem.subtitle = "\(count) file\(count != 1 ? "s" : "")"
            }
        }

        contentItem.artwork = MPMediaItemArtwork(boundsSize: libraryItem.artwork.size, requestHandler: { (_) -> UIImage in
            return libraryItem.artwork
        })

        return contentItem
    }

    // MARK: - MPPlayableContentDelegate

    func playableContentManager(_ contentManager: MPPlayableContentManager, initiatePlaybackOfContentItemAt indexPath: IndexPath, completionHandler: @escaping (Error?) -> Void) {
        guard indexPath.indices.count > 0, let book = self.getBook(at: indexPath) else {
            return
        }

        PlayerManager.shared.load(book) { (loaded) in
            guard loaded else {
                completionHandler(BookPlayerError.UnableToLoadBooks("Unable to load books"))

                return
            }

            PlayerManager.shared.play()

            completionHandler(nil)
        }
    }

    func getBook(at indexPath: IndexPath) -> Book? {
        let item = self.library.getItem(at: indexPath[0])

        if let playlist = item as? Playlist, indexPath.indices.count == 2 {
            if indexPath[0] == 0 {
                return playlist.getBookToPlay()
            }

            return playlist.getBook(at: indexPath[1] - playlistItemsOffset)
        }

        if let book = item as? Book {
            return book
        }

        return nil
    }

    func playableContentManager(_ contentManager: MPPlayableContentManager, didUpdate context: MPPlayableContentManagerContext) {
        print("Update")
    }

    // MARK: - Helpers

    func getLibraryItem(at indexPath: IndexPath) -> LibraryItem? {
        if indexPath.indices.count == 0 || indexPath.count == 2 && indexPath[1] == 0 {
            return nil
        }

        guard let item = self.library.getItem(at: indexPath[0]) else {
            return nil
        }

        guard
            indexPath.indices.count == 2,
            let playlist = item as? Playlist,
            let book = playlist.getBook(at: indexPath[1] - playlistItemsOffset)
            else {
                return item
        }

        return book
    }
}
