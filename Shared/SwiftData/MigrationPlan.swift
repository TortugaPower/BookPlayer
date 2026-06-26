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
        item.uuid = Constants.legacyUuidPlaceholder
      }

      // Skip the match-uuids enqueue for users with no server-side library.
      // SyncService.processContentsResponse rewrites local uuids from server
      // uuids on first sync, so this batch reconcile is only useful for users
      // who already had items synced before the migration.
      guard UserDefaults.standard.bool(forKey: Constants.UserDefaults.hasScheduledLibraryContents) else {
        try context.save()
        return
      }

      let descriptor = FetchDescriptor<SchemaV2.SyncTasksContainer>()
      let containers = try context.fetch(descriptor)
      let tasksContainer = containers.first ?? SchemaV2.SyncTasksContainer()
      if containers.isEmpty {
        context.insert(tasksContainer)
      }

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

        if !uuidsDict.isEmpty {
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
  
  // Stage 3: Backfill external resources for items that were linked to a Hardcover
  // book before hardcover links were modeled as external resources, and enqueue an
  // upload task for each so the link reaches the server.
  static var v2ToV3: MigrationStage = MigrationStage.custom(
    fromVersion: SchemaV2.self,
    toVersion: SchemaV3.self,
    willMigrate: nil,
    didMigrate: { context in
      guard let coreDataContext = injectedCoreDataContext else {
        return
      }

      let providerName = ExternalResource.ProviderName.hardcover.rawValue
      let syncStatus = ExternalResource.SyncStatus.notSynced.rawValue

      var resourcesToUpload: [(uuid: String, relativePath: String, providerId: String)] = []

      // Create the missing hardcover external resources in Core Data.
      coreDataContext.performAndWait {
        let fetchRequest = NSFetchRequest<LibraryItem>(entityName: "LibraryItem")
        fetchRequest.predicate = NSPredicate(format: "hardcoverBook != nil")

        guard let items = try? coreDataContext.fetch(fetchRequest) else { return }

        for item in items {
          guard let hardcoverBook = item.hardcoverBook else { continue }
          let providerId = String(hardcoverBook.id)

          // Skip if the resource already exists
          if item.resourcesArray.contains(where: {
            $0.providerName == providerName && $0.providerId == providerId
          }) {
            continue
          }

          let syncable = SyncableExternalResource(
            providerName: providerName,
            providerId: providerId,
            syncStatus: syncStatus,
            lastSyncedAt: nil,
            processedFile: true,
            hostId: nil
          )
          _ = ExternalResource.create(syncable, libraryItem: item, in: coreDataContext)

          resourcesToUpload.append(
            (uuid: item.uuid, relativePath: item.relativePath, providerId: providerId)
          )
        }

        try? coreDataContext.save()
      }

      // Only enqueue upload tasks for users who already have a server-side library;
      // resources for never-synced users are uploaded on their first sync.
      guard
        UserDefaults.standard.bool(forKey: Constants.UserDefaults.hasScheduledLibraryContents),
        !resourcesToUpload.isEmpty
      else {
        return
      }

      let descriptor = FetchDescriptor<SchemaV3.SyncTasksContainer>()
      let containers = try context.fetch(descriptor)
      let tasksContainer = containers.first ?? SchemaV3.SyncTasksContainer()
      if containers.isEmpty {
        context.insert(tasksContainer)
      }

      var nextPosition = (tasksContainer.tasks.map(\.position).max() ?? -1) + 1

      for resource in resourcesToUpload {
        let taskId = UUID().uuidString
        let task = SchemaV3.UploadExternalResourceTaskModel(
          id: taskId,
          uuid: resource.uuid,
          providerId: resource.providerId,
          providerName: providerName,
          lastSyncedAt: nil,
          syncStatus: syncStatus,
          processedFile: true,
          hostId: nil
        )
        context.insert(task)

        let reference = SchemaV3.SyncTaskReferenceModel(
          uuid: resource.uuid,
          relativePath: resource.relativePath,
          taskID: taskId,
          jobType: .externalResource,
          position: nextPosition
        )
        tasksContainer.tasks.append(reference)
        reference.container = tasksContainer
        nextPosition += 1
      }

      try context.save()
    }
  )
}
