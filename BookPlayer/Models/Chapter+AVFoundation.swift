//
//  Chapter+AVFoundation.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 9/29/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import Foundation
import AVFoundation
import CoreData
import BookPlayerKit

extension Chapter {
    public convenience init(from asset: AVAsset, context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "Chapter", in: context)!
        self.init(entity: entity, insertInto: context)
    }
}
