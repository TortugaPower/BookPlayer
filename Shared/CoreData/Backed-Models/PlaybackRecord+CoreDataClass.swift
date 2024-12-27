//
//  PlaybackRecord+CoreDataClass.swift
//  BookPlayerKit
//
//  Created by Gianni Carlo on 4/23/19.
//  Copyright © 2019 BookPlayer LLC. All rights reserved.
//
//

import CoreData
import Foundation

@objc(PlaybackRecord)
public class PlaybackRecord: NSManagedObject {
  public override func awakeFromInsert() {
    super.awakeFromInsert()
    setPrimitiveValue(Date(), forKey: "date")
  }
}
