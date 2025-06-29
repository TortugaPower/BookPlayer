//
//  HardcoverItem+CoreDataClass.swift
//  BookPlayer
//
//  Created by Jeremy Grenier on 6/28/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import AVFoundation
import CoreData
import Foundation

@objc(HardcoverItem)
public class HardcoverItem: NSManagedObject {
  public convenience init(
    item: SimpleHardcoverItem,
    context: NSManagedObjectContext
  ) {
    let entity = NSEntityDescription.entity(forEntityName: "HardcoverItem", in: context)!
    self.init(entity: entity, insertInto: context)

    self.id = Int32(item.id)
    self.artworkURL = item.artworkURL
    self.title = item.title
    self.author = item.author
    self.status = item.status
  }

  @discardableResult
  func update(with item: SimpleHardcoverItem) -> Self {
    self.id = Int32(item.id)
    self.artworkURL = item.artworkURL
    self.title = item.title
    self.author = item.author
    self.status = item.status
    return self
  }
}
