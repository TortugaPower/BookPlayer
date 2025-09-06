//
//  RealmToSwiftDataMigrationService.swift
//  BookPlayer
//
//  Created by Gianni Carlo on [Current Date].
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Foundation
import RealmSwift
import SwiftData

/// Service to handle the actual data migration from Realm to SwiftData
final public actor RealmToSwiftDataMigrationService: BPLogger {
  let container: ModelContainer

  init(modelContainer: ModelContainer) {
    self.container = modelContainer
  }

  /// Migrate all sync tasks from Realm to SwiftData
  public func migrateRealmDataToSwiftData() async throws {
    Self.logger.info("Starting Realm to SwiftData migration")

    // Check if migration has already been completed
    let migrationKey = "RealmToSwiftDataMigrationCompleted"
    if UserDefaults.standard.bool(forKey: migrationKey) {
      Self.logger.info("Realm to SwiftData migration already completed")
      return
    }

    let realm = try await initializeRealm()
    let context = ModelContext(container)

    do {
      // Get or create the SwiftData container
      let descriptor = FetchDescriptor<SyncTasksContainer>()
      let containers = try context.fetch(descriptor)
      let swiftDataContainer = containers.first ?? SyncTasksContainer()

      if containers.isEmpty {
        context.insert(swiftDataContainer)
      }

      // Get Realm data
      guard let realmContainer = realm.objects(SyncTasksObject.self).first else {
        Self.logger.info("No Realm sync tasks to migrate")
        UserDefaults.standard.set(true, forKey: migrationKey)
        return
      }

      Self.logger.info("Migrating \(realmContainer.tasks.count) sync tasks from Realm to SwiftData")

      var index: Int = 0
      // Migrate each task
      for realmTask in realmContainer.tasks {
        // Create SwiftData task reference
        let swiftDataTask = SyncTaskReferenceModel(
          id: realmTask.id.stringValue,
          relativePath: realmTask.relativePath,
          taskID: realmTask.taskID,
          jobType: realmTask.jobType,
          position: index
        )

        // Migrate the actual task object
        try migrateTaskObject(
          taskID: realmTask.taskID,
          jobType: realmTask.jobType,
          from: realm,
          to: context
        )

        // Add to container
        swiftDataContainer.tasks.append(swiftDataTask)
        swiftDataTask.container = swiftDataContainer

        index += 1
      }

      try context.save()

      Self.logger.info("Successfully migrated sync tasks to SwiftData")
      UserDefaults.standard.set(true, forKey: migrationKey)

    } catch {
      Self.logger.error("Failed to migrate sync tasks to SwiftData: \(error)")
      throw error
    }
  }

  private func initializeRealm() async throws -> Realm {
    return try await RealmManager.shared.initializeRealm(in: self)
  }

  private func migrateTaskObject(
    taskID: String,
    jobType: SyncJobType,
    from realm: Realm,
    to context: ModelContext
  ) throws {
    switch jobType {
    case .upload:
      if let realmTask = realm.objects(UploadTaskObject.self).first(where: { $0.id == taskID }) {
        let swiftDataTask = UploadTaskModel(
          id: realmTask.id,
          relativePath: realmTask.relativePath,
          originalFileName: realmTask.originalFileName,
          title: realmTask.title,
          details: realmTask.details,
          speed: realmTask.speed,
          currentTime: realmTask.currentTime,
          duration: realmTask.duration,
          percentCompleted: realmTask.percentCompleted,
          isFinished: realmTask.isFinished,
          orderRank: realmTask.orderRank,
          lastPlayDateTimestamp: realmTask.lastPlayDateTimestamp,
          type: realmTask.type
        )
        context.insert(swiftDataTask)
      }

    case .update:
      if let realmTask = realm.objects(UpdateTaskObject.self).first(where: { $0.id == taskID }) {
        let swiftDataTask = UpdateTaskModel(
          id: realmTask.id,
          relativePath: realmTask.relativePath,
          title: realmTask.title,
          details: realmTask.details,
          speed: realmTask.speed,
          currentTime: realmTask.currentTime,
          duration: realmTask.duration,
          percentCompleted: realmTask.percentCompleted,
          isFinished: realmTask.isFinished,
          orderRank: realmTask.orderRank,
          lastPlayDateTimestamp: realmTask.lastPlayDateTimestamp,
          type: realmTask.type
        )
        context.insert(swiftDataTask)
      }

    case .move:
      if let realmTask = realm.objects(MoveTaskObject.self).first(where: { $0.id == taskID }) {
        let swiftDataTask = MoveTaskModel(
          id: realmTask.id,
          relativePath: realmTask.relativePath,
          origin: realmTask.origin,
          destination: realmTask.destination
        )
        context.insert(swiftDataTask)
      }

    case .delete, .shallowDelete:
      if let realmTask = realm.objects(DeleteTaskObject.self).first(where: { $0.id == taskID }) {
        let swiftDataTask = DeleteTaskModel(
          id: realmTask.id,
          relativePath: realmTask.relativePath,
          jobType: realmTask.jobType
        )
        context.insert(swiftDataTask)
      }

    case .deleteBookmark:
      if let realmTask = realm.objects(DeleteBookmarkTaskObject.self).first(where: { $0.relativePath == taskID }) {
        let swiftDataTask = DeleteBookmarkTaskModel(
          id: UUID().uuidString,  // Generate new ID since Realm model doesn't have one
          relativePath: realmTask.relativePath,
          time: realmTask.time
        )
        context.insert(swiftDataTask)
      }

    case .setBookmark:
      if let realmTask = realm.objects(SetBookmarkTaskObject.self).first(where: { $0.id == taskID }) {
        let swiftDataTask = SetBookmarkTaskModel(
          id: realmTask.id,
          relativePath: realmTask.relativePath,
          time: realmTask.time,
          note: realmTask.note
        )
        context.insert(swiftDataTask)
      }

    case .renameFolder:
      if let realmTask = realm.objects(RenameFolderTaskObject.self).first(where: { $0.id == taskID }) {
        let swiftDataTask = RenameFolderTaskModel(
          id: realmTask.id,
          relativePath: realmTask.relativePath,
          name: realmTask.name
        )
        context.insert(swiftDataTask)
      }

    case .uploadArtwork:
      if let realmTask = realm.objects(ArtworkUploadTaskObject.self).first(where: { $0.id == taskID }) {
        let swiftDataTask = ArtworkUploadTaskModel(
          id: realmTask.id,
          relativePath: realmTask.relativePath
        )
        context.insert(swiftDataTask)
      }
    }
  }
}
