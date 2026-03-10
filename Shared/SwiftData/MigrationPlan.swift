//
//  MigrationPlan.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 9/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//
import Foundation
import SwiftData
import CoreData

public enum MigrationPlan: SchemaMigrationPlan {
  public static var schemas: [any VersionedSchema.Type] {
    [SchemaV1.self, SchemaV2.self, SchemaV3.self]
  }
  
  public static var stages: [MigrationStage] {
    [v1ToV2, v2ToV3]
  }
  
  public static var injectedCoreDataContext: NSManagedObjectContext?
  
  public static let v1ToV2 = MigrationStage.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)
  
  // Stage 2: Custom logic to populate UUIDs, then drop path
  static let v2ToV3 = MigrationStage.custom(
    fromVersion: SchemaV2.self,
    toVersion: SchemaV3.self,
    willMigrate: { context in
      guard let coreDataContext = injectedCoreDataContext else {
        fatalError("Core Data context was not injected before migration!")
      }
      // 1. Fetch all V2 models (which have both path and optional uuid)
      let items = try context.fetch(FetchDescriptor<SchemaV2.SyncTaskReferenceModel>())
      
      for item in items {
        var foundUUID: String?
        
        // Use the injected context to fetch
        coreDataContext.performAndWait {
          let request = NSFetchRequest<NSManagedObject>(entityName: "LibraryItem")
          request.predicate = NSPredicate(format: "relativePath == %@", item.relativePath)
          request.fetchLimit = 1
          
          if let result = try? coreDataContext.fetch(request).first {
            foundUUID = result.value(forKey: "uuid") as? String
          }
        }
        
        item.uuid = foundUUID ?? UUID().uuidString
      }
      try context.save()
      
    }, didMigrate: nil
  )
}
