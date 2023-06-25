//
//  ManualOrderMigrationUtils.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 26/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import CoreData
import Foundation

extension DataMigrationManager {
  func populateFolderDetails(dataManager: DataManager) {
    let fetch: NSFetchRequest<Folder> = Folder.fetchRequest()
    fetch.returnsObjectsAsFaults = false

    let context = dataManager.getContext()
    context.performAndWait {
      guard let folders = try? context.fetch(fetch) as [Folder] else { return }

      folders.forEach { folder in
        let count = folder.items?.count ?? 0
        folder.details = String.localizedStringWithFormat("files_title".localized, count)
      }

      dataManager.saveContext(context)
    }
  }

  func populateIsFinished(dataManager: DataManager) {
    let fetch: NSFetchRequest<LibraryItem> = LibraryItem.fetchRequest()
    fetch.propertiesToFetch = ["isFinished"]

    let context = dataManager.getContext()
    context.performAndWait {
      guard
        let items = try? context.fetch(fetch) as [LibraryItem]
      else { return }

      items.forEach { item in
        if item.isFinished {
          item.isFinished = true
        } else {
          item.isFinished = false
        }
      }

      dataManager.saveContext(context)
    }
  }
}
