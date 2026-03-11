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
    [SchemaV1.self, SchemaV2.self]
  }
  
  public static var stages: [MigrationStage] {
    [v1ToV2]
  }
  
  public static var injectedCoreDataContext: NSManagedObjectContext?
    
  // Stage 2: Custom logic to populate UUIDs, then drop path
  static let v1ToV2 = MigrationStage.custom(
    fromVersion: SchemaV1.self,
    toVersion: SchemaV2.self,
    willMigrate: { _ in
    },
    didMigrate: { context in
      guard let coreDataContext = injectedCoreDataContext else {
        fatalError("Core Data context was not injected before migration!")
      }
      // 1. Fetch all V2 models (which have both path and optional uuid)
      let items = try context.fetch(FetchDescriptor<SchemaV2.SyncTaskReferenceModel>())
      for item in items {
        item.uuid = "LEGACY_UUID_PLACEHOLDER"
      }
      
      let descriptor = FetchDescriptor<SchemaV2.SyncTasksContainer>()
      let containers = try context.fetch(descriptor)
      let tasksContainer = containers.first ?? SchemaV2.SyncTasksContainer()
      
      var previousOffset = 0
      var loopShouldContinue = true
      repeat {
        var uuidsDict: [String: String] = [:]
        coreDataContext.performAndWait {
          let fetchRequest = NSFetchRequest<LibraryItem>(entityName: "LibraryItem")
          // Fetch only items where the UUID hasn't been set yet
          fetchRequest.fetchLimit = 200
          fetchRequest.fetchOffset = previousOffset
          fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \LibraryItem.relativePath, ascending: true)]
          
          if let itemsToUpdate = try? coreDataContext.fetch(fetchRequest) {
            for item in itemsToUpdate {
              uuidsDict[item.relativePath] = item.uuid
            }
          }
        }
        print("HEY HO AQUI \(uuidsDict.count) AND \(previousOffset)")
        if uuidsDict.count > 0 {
          var parameters = [
            "id": UUID().uuidString,
            "jobType": SyncJobType.matchUuid.rawValue,
            "uuids": uuidsDict,
            "relativePath": "",
            "uuid": ""
          ]
          
          let task = SchemaV2.MatchUuidsTaskModel(
            id: parameters["id"] as? String ?? "",
            uuids: uuidsDict
          )
          context.insert(task)
          
          let nextPosition = (tasksContainer.tasks.map(\.position).max() ?? -1) + 1
          let taskReference = SchemaV2.SyncTaskReferenceModel(
            uuid: "",
            relativePath: "",
            taskID: task.id,
            jobType: SyncJobType.matchUuid,
            position: nextPosition
          )

          tasksContainer.tasks.append(taskReference)
          taskReference.container = tasksContainer
        } else {
          loopShouldContinue = false
        }
        previousOffset += uuidsDict.count
        try context.save()
      } while loopShouldContinue
      
      try context.save()
    }
  )
}
