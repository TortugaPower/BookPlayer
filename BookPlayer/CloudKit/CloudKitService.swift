//
//  CloudKitService.swift
//  BookPlayer
//
//  Created by Kevin Campuzano on 7/5/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import Foundation
import CloudKit
import CoreData
import BookPlayerKit

class CloudKitService {
    private let modelName: String = "BookPlayer"
    let privateCloudDataBase: CKDatabase
    let publicCloudDataBase: CKDatabase
    
    init(){
        let container = CKContainer(identifier: "iCloud.com.tortugapower.audiobookplayer")
        self.privateCloudDataBase = container.privateCloudDatabase
        self.publicCloudDataBase = container.publicCloudDatabase
    }
    
    func fetchOnPrivate(recordType: String, query: CKQuery? = nil) async throws -> [CKRecord] {
        
        var matchingQuery = CKQuery(recordType: recordType,
                                    predicate: NSPredicate(value: true))
        if let customQuery = query {
            matchingQuery = customQuery
        }
        
        let result = try await self.privateCloudDataBase.records(matching: matchingQuery)
        return result.matchResults.compactMap {
            guard case .success(let record) = $0.1 else { return nil }
            return record
        }
    }
    
    func fetchOnPublic(recordType: String, query: CKQuery? = nil) async throws -> [CKRecord] {
        
        var matchingQuery = CKQuery(recordType: recordType,
                                    predicate: NSPredicate(value: true))
        if let customQuery = query {
            matchingQuery = customQuery
        }
        
        let result = try await self.publicCloudDataBase.records(matching: matchingQuery)
        return result.matchResults.compactMap {
            guard case .success(let record) = $0.1 else { return nil }
            return record
        }
    }
    
    func get(by recordName: String) async throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: recordName)
        let record = try await privateCloudDataBase.record(for: recordID)
        return record
    }
    
    func saveOnPrivateDB(itemToSave: CKRecord) async throws -> CKRecord {
        let record = try await privateCloudDataBase.save(itemToSave)
        return record
    }
    
    func saveOnPublicDB(itemToSave: CKRecord) async throws -> CKRecord? {
        let record = try await publicCloudDataBase.save(itemToSave)
        return record
    }
    
    func deleteOfPrivateDB(record: CKRecord) async throws {
        try await self.privateCloudDataBase.deleteRecord(withID: record.recordID)
    }
    
    func deleteOfPublicDB(record: CKRecord) async throws {
        try await self.publicCloudDataBase.deleteRecord(withID: record.recordID)
    }
}
