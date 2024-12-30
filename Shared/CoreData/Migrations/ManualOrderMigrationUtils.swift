//
//  ManualOrderMigrationUtils.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 26/9/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import CoreData
import Foundation

extension DataMigrationManager {
  func populateFolderDetails(dataManager: DataManager) {
    let fetch: NSFetchRequest<Folder> = Folder.fetchRequest()
    fetch.returnsObjectsAsFaults = false
    guard let folders = try? dataManager.getContext().fetch(fetch) as [Folder] else { return }

    folders.forEach { folder in
      let count = folder.items?.count ?? 0
      folder.details = String.localizedStringWithFormat("files_title".localized, count)
    }

    dataManager.saveContext()
  }

  func populateIsFinished(dataManager: DataManager) {
    let fetch: NSFetchRequest<LibraryItem> = LibraryItem.fetchRequest()
    fetch.propertiesToFetch = ["isFinished"]

    guard
      let items = try? dataManager.getContext().fetch(fetch) as [LibraryItem]
    else { return }

    items.forEach { item in
      if item.isFinished {
        item.isFinished = true
      } else {
        item.isFinished = false
      }
    }

    dataManager.saveContext()
  }
}
