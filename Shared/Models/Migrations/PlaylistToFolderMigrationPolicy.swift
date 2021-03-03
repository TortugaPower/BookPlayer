//
//  PlaylistToFolderMigrationPolicy.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/3/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import CoreData
import Foundation

class PlaylistToFolderMigrationPolicy: NSEntityMigrationPolicy {
    override func createDestinationInstances(forSource sInstance: NSManagedObject, in mapping: NSEntityMapping, manager: NSMigrationManager) throws {

        print("=== createDestinationInstancesForSourceInstance: \(sInstance.entity.name)")

        let newFolder = NSEntityDescription.insertNewObject(forEntityName: "Folder", into: manager.destinationContext)

        newFolder.setValue(sInstance.value(forKey: "books"), forKey: "items")
        newFolder.setValue(sInstance.value(forKey: "desc"), forKey: "desc")

//        if let books = sInstance.value(forKey: "books") as? NSOrderedSet {
//            for bookObject in books {
//                guard let book = bookObject as? Book else { continue }
//
//
//                let book = Book.find(with: book.identifier, context: manager.destinationContext)
//
//            }
//
//        }
    }
}
