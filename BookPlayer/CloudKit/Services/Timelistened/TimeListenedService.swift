//
//  TimeListenedService.swift
//  BookPlayer
//
//  Created by Kevin Campuzano on 5/15/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import Foundation
import CloudKit

class TimeListenedService {
    private var cloudKitService: CloudKitService
    
    init(){
        self.cloudKitService = CloudKitService()
    }
    
    func save(backup: BackupObj) async throws -> CKRecord {
        let backupCKRecord = backup.getCKRecord()
        return try await cloudKitService.saveOnPrivateDB(itemToSave: backupCKRecord)
    }
    
    func fetchAll(recordType: String) async throws -> [CKRecord] {
        try await cloudKitService.fetchOnPrivate(recordType: recordType)
    }
    
    func delete(backup: BackupObj) async throws {
        let backupCKRecord = backup.getCKRecord()
        try await cloudKitService.deleteOfPrivateDB(record: backupCKRecord)
    }
    
    func update(backup: BackupObj, newData: Data) async throws {

    }
}
