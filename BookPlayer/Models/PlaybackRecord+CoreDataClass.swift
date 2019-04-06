//
//  PlaybackRecord+CoreDataClass.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/5/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//
//

import CoreData
import Foundation

public class PlaybackRecord: NSManagedObject {
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(Date(), forKey: "date")
    }
}
