//
//  TimeListened.swift
//  BookPlayer
//
//  Created by Kevin Campuzano on 5/17/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import Foundation
import CloudKit

enum TimeListenedFields: String {
    case recordId
    case bookId
    case timeListenedInMiliSeconds
}

class TimeListened: CloudKitRecordProtocol {
    var recordType: String {
        return "Time-Listened"
    }
    
    var recordID: CKRecord.ID?
    
    private var bookId: String
    private var timeListenedInMiliSeconds: TimeInterval
    
    init(bookId: String, timeListenedInMiliSeconds: TimeInterval ){
        self.bookId = bookId
        self.timeListenedInMiliSeconds = timeListenedInMiliSeconds
    }
    
    init?(_ ckRecord: CKRecord) {
        self.recordID = ckRecord.recordID
        self.bookId = ""
        self.timeListenedInMiliSeconds = TimeInterval()
        if let bookId_ = ckRecord[TimeListenedFields.bookId.rawValue] as? String {
            self.bookId = bookId_
        }
        
        if let timeListenedInMiliSeconds_ = ckRecord[TimeListenedFields.timeListenedInMiliSeconds.rawValue] as? TimeInterval {
            self.timeListenedInMiliSeconds = timeListenedInMiliSeconds_
        }
    }
    
    func update(bookId: String, timeListenedInMiliSeconds: TimeInterval) {
        
    }
    
    func getCKRecord() ->CKRecord{
        var recordID_: CKRecord.ID
        if let recordID = recordID  {
            recordID_ = recordID
            
        } else {
            // Creo un nuevo objeto
            recordID_ = CKRecord(recordType: recordType,
                                 recordID: CKRecord.ID(recordName: UUID().uuidString)).recordID
        }
        
        let record = CKRecord(recordType: recordType,
                              recordID: recordID_)
        record.setValue(bookId, forKey: TimeListenedFields.bookId.rawValue)
        record.setValue(timeListenedInMiliSeconds,
                        forKey: TimeListenedFields.timeListenedInMiliSeconds.rawValue)
        return record
    }
}
