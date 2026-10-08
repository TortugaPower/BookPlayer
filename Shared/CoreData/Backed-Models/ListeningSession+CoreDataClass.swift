//
//  ListeningSession+CoreDataClass.swift
//  BookPlayerKit
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//
//

import CoreData
import Foundation

@objc(ListeningSession)
public class ListeningSession: NSManagedObject {
  public override func awakeFromInsert() {
    super.awakeFromInsert()
    setPrimitiveValue(UUID().uuidString, forKey: "id")
    setPrimitiveValue(Date(), forKey: "startedAt")
    setPrimitiveValue(0.0, forKey: "duration")
  }
}
