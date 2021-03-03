//
//  ItemListActions.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 12/11/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import UIKit

protocol ItemListActions: ItemList {
    func sort(by sortType: PlayListSortOrder)
    func delete(_ items: [LibraryItem], mode: DeleteMode)
    func move(_ items: [LibraryItem], to folder: Folder)
}

extension ItemListActions {
    func delete(_ items: [LibraryItem], mode: DeleteMode) {
        DataManager.delete(items, mode: mode)
        self.reloadData()
    }

    func move(_ items: [LibraryItem], to folder: Folder) {
        let selectedFolders = items.compactMap { (item) -> Folder? in
            guard
                let itemPlaylist = item as? Folder,
                itemPlaylist != folder else { return nil }

            return itemPlaylist
        }

        let selectedBooks = items.compactMap { (item) -> Book? in
            item as? Book
        }

        let books = Array(selectedFolders.compactMap { (folder) -> [Book]? in
            guard let books = folder.items else { return nil }

            return books.array as? [Book]
        }.joined())

        let allBooks = books + selectedBooks

        self.library.removeFromItems(NSOrderedSet(array: selectedBooks))
        self.library.removeFromItems(NSOrderedSet(array: selectedFolders))
        folder.addToItems(NSOrderedSet(array: allBooks))
        folder.updateCompletionState()

        DataManager.saveContext()

        self.reloadData()
    }

    func createExportController(_ item: LibraryItem) -> UIViewController? {
        guard let book = item as? Book else { return nil }

        let bookProvider = BookActivityItemProvider(book)

        let shareController = UIActivityViewController(activityItems: [bookProvider], applicationActivities: nil)
        shareController.excludedActivityTypes = [.copyToPasteboard]

        return shareController
    }
}
