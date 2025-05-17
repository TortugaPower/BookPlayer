//
//  CloudKitRecordProtocol.swift
//  BookPlayer
//
//  Created by Kevin Campuzano on 5/15/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import Foundation
import CloudKit

protocol CloudKitRecordProtocol {
    var recordType: String { get }
    var recordID: CKRecord.ID? { get set }
    
    func getCKRecord() -> CKRecord
}
