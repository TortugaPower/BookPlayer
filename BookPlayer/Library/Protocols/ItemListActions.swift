//
//  ItemListActions.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 12/11/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

protocol ItemListActions: ItemList {
    func sort(by sortType: PlayListSortOrder)
    func delete(_ items: [LibraryItem], mode: DeleteMode)
    func move(_ items: [LibraryItem], to playlist: Playlist)
}

extension ItemListActions {
    func delete(_ items: [LibraryItem], mode: DeleteMode) {
        DataManager.delete(items, mode: mode)
        self.reloadData()
    }

    func move(_ items: [LibraryItem], to playlist: Playlist) {
        let selectedPlaylists = items.compactMap({ (item) -> Playlist? in
            guard
                let itemPlaylist = item as? Playlist,
                itemPlaylist != playlist else { return nil }

            return itemPlaylist
        })

        let selectedBooks = items.compactMap({ (item) -> Book? in
            item as? Book
        })

        let books = Array(selectedPlaylists.compactMap({ (playlist) -> [Book]? in
            guard let books = playlist.books else { return nil }

            return books.array as? [Book]
        }).joined())

        let allBooks = books + selectedBooks

        self.library.removeFromItems(NSOrderedSet(array: selectedBooks))
        self.library.removeFromItems(NSOrderedSet(array: selectedPlaylists))
        playlist.addToBooks(NSOrderedSet(array: allBooks))
        playlist.updateCompletionState()

        DataManager.saveContext()

        self.reloadData()
    }

    func createExportController(_ book: Book) -> UIViewController {
        let bookProvider = BookActivityItemProvider(book)

        let shareController = UIActivityViewController(activityItems: [bookProvider], applicationActivities: nil)
        shareController.excludedActivityTypes = [.copyToPasteboard]

        return shareController
    }
}
