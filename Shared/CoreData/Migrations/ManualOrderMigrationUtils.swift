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
  func migrateLibraryOrder(dataManager: DataManager) {
    let libraryService = LibraryService(dataManager: dataManager)
    let library = libraryService.getLibrary()

    guard let items = library.items?.array as? [LibraryItem] else { return }

    for (index, item) in items.enumerated() {
      item.orderRank = Int16(index)
    }

    dataManager.saveContext()

    let folders = items.compactMap({ item -> Folder? in
      if let folder = item as? Folder {
        return folder
      }

      return nil
    })

    self.migrateFolderOrder(folders, dataManager: dataManager)
  }

  func migrateFolderOrder(_ folders: [Folder], dataManager: DataManager) {
    guard !folders.isEmpty else { return }

    var mutatingFolders = folders

    let folder = mutatingFolders.removeFirst()
    guard let items = folder.items?.array as? [LibraryItem] else { return }

    for (index, item) in items.enumerated() {
      item.orderRank = Int16(index)
    }

    dataManager.saveContext()

    let newFolders = items.compactMap({ item -> Folder? in
      if let folder = item as? Folder {
        return folder
      }

      return nil
    })

    self.migrateFolderOrder(mutatingFolders + newFolders, dataManager: dataManager)
  }

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
}
