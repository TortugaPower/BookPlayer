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
    guard let library = try? dataManager.getLibrary(),
          let items = library.items?.array as? [LibraryItem] else { return }

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
      // Migrate and overwrite nil folder-artwork data
      if folder.artworkData == nil,
         item.artworkData != nil {
        folder.artworkData = item.artworkData
      }

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
}
