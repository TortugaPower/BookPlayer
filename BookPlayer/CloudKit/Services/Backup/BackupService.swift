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

class BackupService {
    
    private var cloudKitService: CloudKitService
    
    lazy var newData: Data? = {
        let storeURL = DataMigrationManager().getStoreURL()
        return FileManager.default.contents(atPath: storeURL.path)
    }()
    
    init(){
        self.cloudKitService = CloudKitService()
    }
    
    func saveAndUpdateIfNeeded() async {
        do {
            let backupItem = await get()
            if let backupItem_ = backupItem {
                try await update(model: backupItem_)
                return
            } else {
                try await save()
            }
        } catch {
            
        }
    }
    
    @discardableResult func save() async throws -> CKRecord {
        guard let newData_ = newData else {
            fatalError()
        }
        let backup = BackupObj(data: newData_)
        let backupCKRecord = backup.getCKRecord()
        return try await cloudKitService.saveOnPrivateDB(itemToSave: backupCKRecord)
    }
    
    // Trae toda una lista de CKRecords
    func fetchAll(recordType: String) async throws -> [CKRecord] {
        try await cloudKitService.fetchOnPrivate(recordType: recordType)
    }
    
    func get() async -> BackupObj? {
        do {
            let record = try await cloudKitService.get(by: BackupObj.RECORD_NAME)
            guard let backupObj = BackupObj(record) else {
                return nil
            }
            return backupObj
        } catch {
            return nil
        }
    }
    
    func delete(backup: BackupObj) async throws {
        let backupCKRecord = backup.getCKRecord()
        try await cloudKitService.deleteOfPrivateDB(record: backupCKRecord)
    }
    
    func update(model: BackupObj) async throws {
        guard let newData_ = newData else {
            fatalError()
        }
        
        guard let newRecord = try await cloudKitService.fetchOnPrivate(recordType: model.recordType).first else {
            return
        }
        
        newRecord.setValue(newData_, forKey: BackupObjFields.data.rawValue)
         _ = try await cloudKitService.saveOnPrivateDB(itemToSave: newRecord)
        model.update(newData: newData_)
    }
    
}
