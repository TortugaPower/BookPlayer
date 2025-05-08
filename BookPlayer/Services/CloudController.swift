//
//  CloudController.swift
//  BookPlayer
//
//  Created by Kevin Campuzano on 7/5/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import Foundation
import CloudKit
import CoreData
import BookPlayerKit

class CloudController {
    private let modelName: String = "BookPlayer"
    let container: CKContainer
    let databasePublic: CKDatabase
    let databasePrivate: CKDatabase
    
    init(){
        self.container = CKContainer.default()
        self.databasePublic = container.publicCloudDatabase
        self.databasePrivate = container.privateCloudDatabase
    }
    
    func save(data: Data){
        // El record tiene que ser el .sqlite
        do {
            
            let storeURL =  FileManager.default.containerURL(
              forSecurityApplicationGroupIdentifier: Constants.ApplicationGroupIdentifier)!
              .appendingPathComponent("\(self.modelName).sqlite")
            let targetURL = storeURL.deletingLastPathComponent()
            
            let fileManager = FileManager.default
            let wal = storeURL.lastPathComponent + "-wal"
            let shm = storeURL.lastPathComponent + "-shm"
            let destinationWal = targetURL
              .appendingPathComponent(wal)
            let destinationShm = targetURL
              .appendingPathComponent(shm)
            // cleanup in case
            try? fileManager.removeItem(at: destinationWal)
            try? fileManager.removeItem(at: destinationShm)

            
            try fileManager.removeItem(at: storeURL)
            
            try fileManager.moveItem(at: destinationURL, to: storeURL)
            
//            try await databasePrivate.save(<#T##record: CKRecord##CKRecord#>)
        } catch {
            print("Error creating project: \(error)")
        }
    }
}
