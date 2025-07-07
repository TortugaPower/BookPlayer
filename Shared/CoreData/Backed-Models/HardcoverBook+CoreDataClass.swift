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

@objc(HardcoverBook)
public class HardcoverBook: NSManagedObject {
  public convenience init(
    item: SimpleHardcoverBook,
    context: NSManagedObjectContext
  ) {
    let entity = NSEntityDescription.entity(forEntityName: "HardcoverBook", in: context)!
    self.init(entity: entity, insertInto: context)

    self.id = Int32(item.id)
    self.artworkURL = item.artworkURL
    self.title = item.title
    self.author = item.author
    self.status = item.status
    self.userBookID = Int32(item.userBookID ?? 0)
  }

  @discardableResult
  func update(with item: SimpleHardcoverBook) -> Self {
    self.id = Int32(item.id)
    self.artworkURL = item.artworkURL
    self.title = item.title
    self.author = item.author
    self.status = item.status
    self.userBookID = Int32(item.userBookID ?? 0)
    return self
  }
}
