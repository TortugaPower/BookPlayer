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
    func delete(_ items: [LibraryItem], mode: DeleteMode) throws
    func move(_ items: [LibraryItem], to folder: Folder) throws
}

extension ItemListActions {
    func delete(_ items: [LibraryItem], mode: DeleteMode) throws {
      try DataManager.delete(items, library: self.library, mode: mode)
      self.reloadData()
    }

    func move(_ items: [LibraryItem], to folder: Folder) throws {
        try DataManager.moveItems(items, into: folder)
        self.reloadData()
    }

    func createExportController(_ item: LibraryItem) -> UIViewController? {
//        guard let book = item as? Book else { return nil }
//
//        let bookProvider = BookActivityItemProvider(book)
//
//        let shareController = UIActivityViewController(activityItems: [bookProvider], applicationActivities: nil)
//        shareController.excludedActivityTypes = [.copyToPasteboard]
//
//        return shareController
      return nil
    }
}
