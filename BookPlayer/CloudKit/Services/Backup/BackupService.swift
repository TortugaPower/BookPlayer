//
//  BackupService.swift
//  BookPlayer
//
//  Created by Kevin Campuzano on 5/15/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import Foundation
import CloudKit
import BookPlayerKit

//      let newData = "newDataExtra"
//      let storeURL =  FileManager.default.containerURL(
//        forSecurityApplicationGroupIdentifier: Constants.ApplicationGroupIdentifier)!
//        .appendingPathComponent("BookPlayer.sqlite")
//      if let newDataIntoData = FileManager.default.contents(atPath: storeURL.path) {
//          await CloudKitService().saveOnPrivateDB(item: newData,
//                                       data: newDataIntoData)
//      }
//      // matar el archivo, y tb el wal y otra cosa
//
//      if let recordData = await CloudKitService().getOfPrivateDB(by: "5542ED5D-B861-4F48-A7D2-B5EE15DDC9D5")?.data {
//          try? recordData.write(to: storeURL)
//      }

class BackupService {
    
    private var cloudKitService: CloudKitService
    
    init(){
        self.cloudKitService = CloudKitService()
    }
    
    func save() async throws -> CKRecord {
        let storeURL =  FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Constants.ApplicationGroupIdentifier)!
            .appendingPathComponent("\(DataMigrationManager.modelName).sqlite")
        guard let newData = FileManager.default.contents(atPath: storeURL.path) else {
            fatalError()
        }
        
        let backup = BackupObj(data: newData)
        let backupCKRecord = backup.getCKRecord()
        return try await cloudKitService.saveOnPrivateDB(itemToSave: backupCKRecord)
        
    }
    
    // Trae toda una lista de CKRecords
    func fetchAll(recordType: String) async throws -> [CKRecord] {
        try await cloudKitService.fetchOnPrivate(recordType: recordType)
    }
    
    func get() async throws -> BackupObj {
        let record = try await cloudKitService.get(by: BackupObj.RECORD_NAME)
        guard let backupObj = BackupObj(record) else {
            fatalError()
        }
        return backupObj
    }
    
    func delete(backup: BackupObj) async throws {
        let backupCKRecord = backup.getCKRecord()
        try await cloudKitService.deleteOfPrivateDB(record: backupCKRecord)
    }
    
    func update(backup: BackupObj, newData: Data) async throws {
        guard let newRecord = try await cloudKitService.fetchOnPrivate(recordType: backup.recordType).first else {
            return
        }
        
        newRecord.setValue(newData, forKey: BackupObjFields.data.rawValue)
         _ = try await cloudKitService.saveOnPrivateDB(itemToSave: newRecord)
        backup.update(newData: newData)
    }
    
}
