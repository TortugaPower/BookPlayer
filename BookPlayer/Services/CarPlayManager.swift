//
//  CarPlayManager.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 8/12/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import MediaPlayer
import UIKit

enum BookPlayerError: Error {
    case UnableToLoadBooks(String)
}

enum IndexDepth: Int {
    case library = 0
    case playlist = 1
}

class CarPlayManager: NSObject, MPPlayableContentDataSource, MPPlayableContentDelegate {
    static let shared = CarPlayManager()

    var library: Library!

    private override init() {
        self.library = DataManager.getLibrary()
    }

    func numberOfChildItems(at indexPath: IndexPath) -> Int {
        if indexPath.indices.count == IndexDepth.library.rawValue {
            return self.library.items?.count ?? 0
        }

        guard let items = self.library.items?.array as? [LibraryItem],
            let playlist = items[indexPath[IndexDepth.library.rawValue]] as? Playlist,
            let count = playlist.books?.count else {
            return 0
        }

        return count
    }

    func contentItem(at indexPath: IndexPath) -> MPContentItem? {
        guard let items = self.library.items?.array as? [LibraryItem] else {
            return nil
        }

        // Populate playlist content
        if indexPath.indices.count > IndexDepth.playlist.rawValue,
            let playlist = items[indexPath[IndexDepth.library.rawValue]] as? Playlist,
            let books = playlist.books?.array as? [Book] {
            let book = books[indexPath[IndexDepth.playlist.rawValue]]
            let item = MPContentItem(identifier: book.identifier)
            item.isPlayable = true
            item.title = book.title
            item.subtitle = book.author
            item.playbackProgress = Float(book.progress)
            item.artwork = MPMediaItemArtwork(boundsSize: book.artwork.size,
                                              requestHandler: { (_) -> UIImage in
                                                  book.artwork
            })
            return item
        }

        // Populate library content
        let libraryItem = items[indexPath[IndexDepth.library.rawValue]]

        // Playlists identifiers weren't unique, this is a quick fix
        if libraryItem.identifier == libraryItem.title {
            libraryItem.identifier = "\(libraryItem.title!)\(Date().timeIntervalSince1970)"
        }

        let item = MPContentItem(identifier: libraryItem.identifier)
        item.title = libraryItem.title

        item.playbackProgress = Float(libraryItem.progress)
        item.artwork = MPMediaItemArtwork(boundsSize: libraryItem.artwork.size,
                                          requestHandler: { (_) -> UIImage in
                                              libraryItem.artwork
        })

        if let book = libraryItem as? Book {
            item.subtitle = book.author
            item.isContainer = false
            item.isPlayable = true
        } else if let playlist = libraryItem as? Playlist {
            item.subtitle = playlist.info()
            item.isContainer = true
        }

        return item
    }

    func playableContentManager(_ contentManager: MPPlayableContentManager, initiatePlaybackOfContentItemAt indexPath: IndexPath, completionHandler: @escaping (Error?) -> Void) {
        guard let items = self.library.items?.array as? [LibraryItem] else {
            completionHandler(BookPlayerError.UnableToLoadBooks("Unable to load books"))
            return
        }

        var book: Book!

        if indexPath.indices.count > IndexDepth.playlist.rawValue,
            let playlist = items[indexPath[IndexDepth.library.rawValue]] as? Playlist,
            let books = playlist.books?.array as? [Book] {
            book = books[indexPath[IndexDepth.playlist.rawValue]]
        } else {
            book = items[indexPath[IndexDepth.library.rawValue]] as? Book
        }

        guard book != nil else {
            completionHandler(BookPlayerError.UnableToLoadBooks("Unable to load books"))
            return
        }

        let message: [AnyHashable: Any] = ["command": "play",
                                           "identifier": book.identifier!]

        NotificationCenter.default.post(name: .messageReceived, object: nil, userInfo: message)

        // Hack to show the now-playing-view on simulator
        // It has side effects on the initial state of the buttons of that view
        // But it's meant for development use only
        #if targetEnvironment(simulator)
        DispatchQueue.main.async {
            UIApplication.shared.endReceivingRemoteControlEvents()
            UIApplication.shared.beginReceivingRemoteControlEvents()
        }
        #endif

        completionHandler(nil)
    }

    func childItemsDisplayPlaybackProgress(at indexPath: IndexPath) -> Bool {
        return true
    }

    func setNowPlayingInfo(with book: Book) {
        var identifiers = [book.identifier!]

        if let playlist = book.playlist {
            identifiers.append(playlist.identifier)
        }

        MPPlayableContentManager.shared().nowPlayingIdentifiers = identifiers
    }
}
