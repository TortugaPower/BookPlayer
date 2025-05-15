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

class Record {
    public var recordID: CKRecord.ID?
    public var item: String
    public var data: Data
    
    init(item: String, data: Data){
        self.item = item
        self.data = data
    }
    
    init?(_ ckRecord: CKRecord){
        guard let item = ckRecord[RecordFields.item.rawValue] as? String,
              let data = ckRecord[RecordFields.data.rawValue] as? Data
                else { return nil }
        self.item = item
        self.data = data
        self.recordID = ckRecord.recordID
    }
    
    func getCKRecord() -> CKRecord {
        var recordID_: CKRecord.ID
        
        if let recordID = recordID  {
            recordID_ = recordID
            // Creo un nuevo objeto
        } else {
            recordID_ = CKRecord(recordType: CloudKitService.RecordType,
                                 recordID: CKRecord.ID(recordName: UUID().uuidString)).recordID
        }
        
        let record = CKRecord(recordType: "BookPlayerRecord",
                              recordID: recordID_)
        record.setValue(item,
                        forKey: RecordFields.item.rawValue)
        record.setValue(data,
                        forKey: RecordFields.data.rawValue)
        return record
    }
}

enum RecordFields: String {
    case recordId
    case item
    case data
}



class CloudKitService {
    private let modelName: String = "BookPlayer"
    public static let RecordType: String = "BookPlayerRecord"
    let database: CKDatabase
    
    init(){
        let container = CKContainer(identifier: "iCloud.com.tortugapower.audiobookplayer")
        self.database = container.privateCloudDatabase
    }
    
    /// Adding record to private Database using `save`.
    /// This will save a Dictionary
    func save(item: String,
              data: Data) async -> Record? {
        do {
            let itemToSave = Record(item: item, data: data)
            let itemRecord = itemToSave.getCKRecord()
            let record = try await database.save(itemRecord)
            let res = Record(record)
            return res
        } catch {
            print("Error creating Item: \(error)")
            return nil
        }
    }
    
//    func fetchAll() async throws -> [Record]? {
//        let query = CKQuery(
//            recordType: CloudKitService.RecordType,
//            predicate: NSPredicate(value: true) // Fetch all records
//        )
//        
//        let records = await database
//        
//        database.perform(query, inZoneWith: nil) {(records, error) in
//            if let error = error {
//                print("Error fetching Items: \(error)")
//                return
//            }
//            
//            return records
//        }
        // Sort by a queryable field (e.g., title)
//        query.sortDescriptors = [NSSortDescriptor(key: "item", ascending: true)]
//        
//        let result = try await database.records(matching: query)
//        return result.matchResults.compactMap {
//            guard case .success(let record) = $0.1 else { return nil }
//            return TodoItem(record: record)
//        }
//    }
    
    func get(by recordName: String) async -> Record? {
        do {
            let recordID = CKRecord.ID(recordName: recordName)
            let record = try await self.database.record(for: recordID)
            let res = Record(record)
            return res
        } catch {
            print("Error fetching Item: \(error)")
            return nil
        }
    }
    
    func update(newItem: String,
                newData: Data,
                record: Record) async -> Void {
        do {
            let ckRecord = try await self.database.record(for: record.getCKRecord().recordID)
            ckRecord.setValue(newItem, forKey: RecordFields.item.rawValue)
            ckRecord.setValue(newData, forKey: RecordFields.data.rawValue)
            let _ = try await self.database.save(ckRecord)
            record.item = newItem
            record.data = newData
        } catch {
            print("Error updating record: \(error)")
            return
        }
    }
    
    func delete(record: Record) async -> Void {
        do {
            let ckRecrod = record.getCKRecord()
            try await self.database.deleteRecord(withID: ckRecrod.recordID)
        } catch {
            print("Error deleting record: \(error)")
            return
        }
    }
}
