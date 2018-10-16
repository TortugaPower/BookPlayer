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

class CarPlayManager: NSObject, MPPlayableContentDataSource, MPPlayableContentDelegate {
    static let shared = CarPlayManager()

    var library: Library!

    private override init() {
        self.library = DataManager.getLibrary()
    }

    func reload() {
        MPPlayableContentManager.shared().reloadData()
    }

    func numberOfChildItems(at indexPath: IndexPath) -> Int {
        if indexPath.indices.count == 0 {
            return self.library.items?.count ?? 0
        }

        guard let playlist = self.library.getItem(at: indexPath[0]) as? Playlist, let count = playlist.books?.count else {
            return 0
        }

        return count
    }

    func beginLoadingChildItems(at indexPath: IndexPath, completionHandler: @escaping (Error?) -> Void) {
        completionHandler(nil)
    }

    func contentItem(at indexPath: IndexPath) -> MPContentItem? {
        guard let libraryItem = self.library.getItem(at: indexPath) else {
            return nil
        }

        let contentItem = MPContentItem.init()

        contentItem.title = libraryItem.title
        contentItem.playbackProgress = Float(libraryItem.currentTime / libraryItem.duration)

        if let book = libraryItem as? Book {
            contentItem.subtitle = "\(libraryItem.isCompleted ? "✓ " : "")\(book.author ?? "")"
            contentItem.isPlayable = true
        }

        if libraryItem is Playlist {
            contentItem.isContainer = true
            contentItem.subtitle = "\(libraryItem.isCompleted ? "✓" : "")"
        }

        contentItem.artwork = MPMediaItemArtwork(boundsSize: libraryItem.artwork.size, requestHandler: { (_) -> UIImage in
            return libraryItem.artwork
        })

        return contentItem
    }

    func playableContentManager(_ contentManager: MPPlayableContentManager, initiatePlaybackOfContentItemAt indexPath: IndexPath, completionHandler: @escaping (Error?) -> Void) {
        if indexPath.indices.count == 0 {
            return
        }

        var item = self.library.getItem(at: indexPath[0])

        if let playlist = item as? Playlist, indexPath.indices.count == 2 {
            item = playlist.getBook(at: indexPath[1])
        }

        guard let book = item as? Book else {
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

    func playableContentManager(_ contentManager: MPPlayableContentManager, didUpdate context: MPPlayableContentManagerContext) {
        print("Update")
    }
}
