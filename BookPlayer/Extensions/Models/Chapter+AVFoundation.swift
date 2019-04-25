//
//  Chapter+AVFoundation.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/23/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import AVFoundation
import BookPlayerKit
import CoreData
import Foundation

extension Chapter {
    convenience init(from asset: AVAsset, context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "Chapter", in: context)!
        self.init(entity: entity, insertInto: context)
    }
}
