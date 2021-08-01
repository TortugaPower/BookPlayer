//
//  Folder+AVFoundation.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 21/7/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import AVFoundation
import BookPlayerKit
import CoreData
import Foundation

extension Folder {
  convenience init(from fileURL: URL, context: NSManagedObjectContext) {
    let entity = NSEntityDescription.entity(forEntityName: "Folder", in: context)!
    self.init(entity: entity, insertInto: context)
    let fileTitle = fileURL.lastPathComponent
    self.identifier = "\(fileTitle)\(Date().timeIntervalSince1970)"
    self.relativePath = fileURL.relativePath(to: DataManager.getProcessedFolderURL())
    self.title = fileTitle
    self.originalFileName = fileTitle
  }
}
