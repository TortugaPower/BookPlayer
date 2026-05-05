//
//  UUIDMigrationPolicy.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 9/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import CoreData

class UUIDMigrationPolicy: NSEntityMigrationPolicy {
  
  override func createDestinationInstances(
    forSource sInstance: NSManagedObject,
    in mapping: NSEntityMapping,
    manager: NSMigrationManager
  ) throws {
    // 1. Create the new destination object in the destination context
    guard let destinationEntityName = mapping.destinationEntityName else { return }
    let destinationInstance = NSEntityDescription.insertNewObject(
      forEntityName: destinationEntityName,
      into: manager.destinationContext
    )
    // 2. Copy over all the existing attributes from the old record
    let destinationKeys = destinationInstance.entity.attributesByName.keys
    for key in sInstance.entity.attributesByName.keys {
      if destinationKeys.contains(key) {
        destinationInstance.setValue(sInstance.value(forKey: key), forKey: key)
      }
    }
    // 3. Generate and assign the new required UUID
    destinationInstance.setValue(UUID().uuidString, forKey: "uuid")
    // 4. Tell the migration manager to associate the old record with the new one
    manager.associate(
      sourceInstance: sInstance,
      withDestinationInstance: destinationInstance,
      for: mapping
    )
  }
}
