//
//  Chapter+CoreDataClass.swift
//  BookPlayerKit
//
//  Created by Gianni Carlo on 9/21/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//
//

import Foundation
import CoreData

@objc(Chapter)
public class Chapter: NSManagedObject, Codable {
    var end: TimeInterval {
        return start + duration
    }

    enum CodingKeys: String, CodingKey {
        case duration, index, start, title
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(duration, forKey: .duration)
        try container.encode(index, forKey: .index)
        try container.encode(start, forKey: .start)
        try container.encode(title, forKey: .title)
    }

    public required convenience init(from decoder: Decoder) throws {
        // Create NSEntityDescription with NSManagedObjectContext
        guard let contextUserInfoKey = CodingUserInfoKey.context,
            let managedObjectContext = decoder.userInfo[contextUserInfoKey] as? NSManagedObjectContext,
            let entity = NSEntityDescription.entity(forEntityName: "Chapter", in: managedObjectContext) else {
                fatalError("Failed to decode Chapter")
        }
        self.init(entity: entity, insertInto: nil)

        let values = try decoder.container(keyedBy: CodingKeys.self)
        duration = try values.decode(Double.self, forKey: .duration)
        index = try values.decode(Int16.self, forKey: .index)
        start = try values.decode(Double.self, forKey: .start)
        title = try values.decode(String.self, forKey: .title)
    }
}
