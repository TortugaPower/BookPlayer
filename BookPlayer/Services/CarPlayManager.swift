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

enum IndexGuide {
    case tab

    var recentlyPlayed: Int {
        return 1
    }

    case library
    case folder

    var count: Int {
        switch self {
        case .tab:
            return 1
        case .library:
            return 2
        case .folder:
            return 3
        }
    }

    var content: Int {
        switch self {
        case .tab:
            return 0
        case .library:
            return 1
        case .folder:
            return 2
        }
    }
}

class CarPlayManager: NSObject, MPPlayableContentDataSource, MPPlayableContentDelegate {
    static let shared = CarPlayManager()

    var library: Library!

    typealias Tab = (identifier: String, title: String, imageName: String)
    let tabs: [Tab] = [("tab-library", "library_title".localized, "carplayLibrary"),
                       ("tab-recent", "carplay_recent_title".localized, "carplayRecent")]

    private override init() {
        self.library = DataManager.getLibrary()
    }

    func createTabItem(for indexPath: IndexPath) -> MPContentItem {
        let tab = self.tabs[indexPath[IndexGuide.tab.content]]
        let item = MPContentItem(identifier: tab.identifier)
        item.title = tab.title
        item.isContainer = true
        item.isPlayable = false
        if let tabImage = UIImage(named: tab.imageName) {
            item.artwork = MPMediaItemArtwork(boundsSize: tabImage.size, requestHandler: { _ -> UIImage in
                tabImage
            })
        }

        return item
    }

    func numberOfChildItems(at indexPath: IndexPath) -> Int {
        if indexPath.indices.isEmpty {
            return 2
        }

        guard let items = self.getItems(for: indexPath) else {
            return 0
        }

        if indexPath.indices.count == IndexGuide.library.count - 1 {
            return items.count
        }

        guard let folder = items[indexPath[IndexGuide.library.content]] as? Folder,
            let count = folder.items?.count else {
            return 0
        }

        return count
    }

    func contentItem(at indexPath: IndexPath) -> MPContentItem? {
        // Populate tabs
        if indexPath.indices.count == IndexGuide.tab.count {
            return self.createTabItem(for: indexPath)
        }

        guard let items = self.getItems(for: indexPath) else {
            return nil
        }

        // Populate folder content
        if indexPath.indices.count == IndexGuide.folder.count,
           let folder = items[indexPath[IndexGuide.library.content]] as? Folder,
           let books = folder.items?.array as? [Book] {
            let book = books[indexPath[IndexGuide.folder.content]]
            let item = MPContentItem(identifier: book.identifier)
            item.isPlayable = true
            item.title = book.title
            item.subtitle = book.author
            item.playbackProgress = Float(book.progressPercentage)

            if let artwork = book.getArtwork(for: ThemeManager.shared.currentTheme) {
                item.artwork = MPMediaItemArtwork(boundsSize: artwork.size,
                                                  requestHandler: { (_) -> UIImage in
                                                      artwork
                })
            }

            return item
        }

        let libraryItem = items[indexPath[IndexGuide.library.content]]

        // Folders identifiers weren't unique, this is a quick fix
        if libraryItem.identifier == libraryItem.title {
            libraryItem.identifier = "\(libraryItem.title!)\(Date().timeIntervalSince1970)"
        }

        let item = MPContentItem(identifier: libraryItem.identifier)
        item.title = libraryItem.title

        item.playbackProgress = Float(libraryItem.progressPercentage)
        if let artwork = libraryItem.getArtwork(for: ThemeManager.shared.currentTheme) {
            item.artwork = MPMediaItemArtwork(boundsSize: artwork.size,
                                              requestHandler: { (_) -> UIImage in
                                                artwork
                                              })
        }

        if let book = libraryItem as? Book {
            item.subtitle = book.author
            item.isContainer = false
            item.isPlayable = true
        } else if let folder = libraryItem as? Folder {
            item.subtitle = folder.info()
            item.isContainer = indexPath[0] != IndexGuide.tab.recentlyPlayed
            item.isPlayable = indexPath[0] == IndexGuide.tab.recentlyPlayed
        }

        return item
    }

    func playableContentManager(_ contentManager: MPPlayableContentManager, initiatePlaybackOfContentItemAt indexPath: IndexPath, completionHandler: @escaping (Error?) -> Void) {
        guard let items = self.getItems(for: indexPath) else {
            completionHandler(BookPlayerError.UnableToLoadBooks("carplay_library_error".localized))
            return
        }

        var book: Book!

        if indexPath.indices.count == IndexGuide.folder.count,
            let folder = items[indexPath[IndexGuide.library.content]] as? Folder,
            let books = folder.items?.array as? [Book] {
            book = books[indexPath[IndexGuide.folder.content]]
        } else {
            if indexPath[0] == IndexGuide.tab.recentlyPlayed,
                let folder = items[indexPath[IndexGuide.library.content]] as? Folder {
                book = folder.getBookToPlay()
            } else {
                book = items[indexPath[IndexGuide.library.content]] as? Book
            }
        }

        guard book != nil else {
            completionHandler(BookPlayerError.UnableToLoadBooks("carplay_library_error".localized))
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

    private func getItems(for indexPath: IndexPath) -> [LibraryItem]? {
        // Recently played items
        if indexPath[0] == IndexGuide.tab.recentlyPlayed {
            return self.library.getItemsOrderedByDate()
        }

        // Library items
        return self.library.items?.array as? [LibraryItem]
    }

    func setNowPlayingInfo(with book: Book) {
        var identifiers = [book.identifier!]

        if let folder = book.folder {
            identifiers.append(folder.identifier)
        }

        MPPlayableContentManager.shared().nowPlayingIdentifiers = identifiers
        MPPlayableContentManager.shared().reloadData()
    }
}
