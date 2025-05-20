//
//  BackupObj.swift
//  BookPlayer
//
//  Created by Kevin Campuzano on 5/15/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//
import CloudKit
enum BackupObjFields: String {
    case recordId
    case data
}

class BackupObj: CloudKitRecordProtocol {
    var recordType: String {
        return "Backup"
    }
    
    public static let RECORD_NAME = "backup-db"
    
    var recordID: CKRecord.ID?
    
    private var data: Data
    
    init(data: Data){
        self.data = data
    }
    
    init?(_ ckRecord: CKRecord){
        guard let data_ = ckRecord[BackupObjFields.data.rawValue] as? Data
                else { return nil }
        recordID = ckRecord.recordID
        data = data_
    }
    
    func update(newData: Data) {
        self.data = newData
    }
    
    func getData() -> Data {
        return data
    }
    
    func getCKRecord() -> CKRecord {
        var recordID_: CKRecord.ID
        
        if let recordID = recordID  {
            recordID_ = recordID
            
        } else {
            // Creo un nuevo objeto
            recordID_ = CKRecord(recordType: recordType,
                                 recordID: CKRecord.ID(recordName: BackupObj.RECORD_NAME)).recordID
        }
        
        let record = CKRecord(recordType: recordType,
                              recordID: recordID_)
        record.setValue(data,
                        forKey: BackupObjFields.data.rawValue)
        return record
    }
}
