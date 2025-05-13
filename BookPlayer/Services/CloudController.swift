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
    public var item: Dictionary<String, AnyObject> // Esto se reemplaza por el data
    
    
    init(item: Dictionary<String, AnyObject>){
        self.item = item
    }
    
    init?(_ ckRecord: CKRecord){
        guard let item = ckRecord[RecordFields.item.rawValue] as? Dictionary<String, AnyObject>
                else { return nil }
        self.item = item
        self.recordID = ckRecord.recordID
    }
    
    
    func getCKRecord() -> CKRecord {
        var recordID_: CKRecord.ID
        
        if let recordID = recordID  {
            recordID_ = recordID
            // Creo un nuevo objeto
        } else {
            recordID_ = CKRecord(recordType: "BookPlayerRecord",
                                 recordID: CKRecord.ID(recordName: UUID().uuidString)).recordID
        }
        
        var record = CKRecord(recordType: "BookPlayerRecord",
                              recordID: recordID_)
        record.setValue(item,
                        forKey: RecordFields.item.rawValue)
        return record
    }
}

enum RecordFields: String {
    case recordId
    case item
}



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
    
    /// Adding record to private Database using `save`.
    /// This will save a Dictionary
    func save(data: Dictionary<String, AnyObject>) async -> Record? {
        do {
            let itemToSave = Record(item: data)
            let itemRecord = itemToSave.getCKRecord()
            let record = try await databasePrivate.save(itemRecord)
            let res = Record(record)
            return res
        } catch {
            print("Error creating Item: \(error)")
            return nil
        }
    }
    
    func get(recordName: String) async -> Record? {
        do {
            let recordID = CKRecord.ID(recordName: recordName)
            let record = try await self.databasePrivate.record(for: recordID)
            let res = Record(record)
            return res
        } catch {
            print("Error fetching Item: \(error)")
            return nil
        }
    }
    
    func update(newData: Dictionary<String, AnyObject>,
                record: Record) async -> Void {
        do {
            let ckRecord = try await self.databasePrivate.record(for: record.getCKRecord().recordID)
            ckRecord.setValue(newData, forKey: RecordFields.item.rawValue)
            let savedRecord = try await self.databasePrivate.save(ckRecord)
            record.item = newData
        } catch {
            print("Error updating record: \(error)")
            return
        }
    }
    
    func delete(record: Record) async -> Void {
        do {
            let ckRecrod = record.getCKRecord()
            try await self.databasePrivate.deleteRecord(withID: ckRecrod.recordID)
        } catch {
            print("Error deleting record: \(error)")
            return
        }
    }
}
