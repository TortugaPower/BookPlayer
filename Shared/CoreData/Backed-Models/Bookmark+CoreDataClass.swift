//
//  Bookmark+CoreDataClass.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//
//

import Foundation
import CoreData

@objc(Bookmark)
public class Bookmark: NSManagedObject {
  public convenience init(with time: Double, type: BookmarkType, context: NSManagedObjectContext) {
    let entity = NSEntityDescription.entity(forEntityName: "Bookmark", in: context)!
    self.init(entity: entity, insertInto: context)
    
    self.time = time
    self.type = type
  }
}
