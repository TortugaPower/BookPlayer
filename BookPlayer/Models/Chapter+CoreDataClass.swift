//
//  Chapter+CoreDataClass.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/9/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//
//

import Foundation
import CoreData
import AVFoundation

public class Chapter: NSManagedObject {
    var end: TimeInterval {
        return start + duration
    }
    convenience init(from asset: AVAsset, context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "Chapter", in: context)!
        self.init(entity: entity, insertInto: context)

    }
}
