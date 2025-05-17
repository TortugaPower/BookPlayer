//
//  DataMigrationManager.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 19/2/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import CoreData
import Foundation
import UIKit

public final class DataMigrationManager: BPLogger {
  public static let modelName: String = "BookPlayer"
  private let currentModel: NSManagedObjectModel
  private let storeURL: URL
  private var storeModel: NSManagedObjectModel?

  public init() {
    self.currentModel = .model(named: DataMigrationManager.modelName)
    let storeURL =  FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: Constants.ApplicationGroupIdentifier)!
      .appendingPathComponent("\(DataMigrationManager.modelName).sqlite")
    self.storeURL = storeURL
    self.storeModel = NSManagedObjectModel.modelVersionsFor(modelNamed: DataMigrationManager.modelName)
      .filter {
        self.store(at: storeURL, isCompatibleWithModel: $0)
      }.first
  }

  public func getCoreDataStack() -> CoreDataStack {
    return CoreDataStack(modelName: DataMigrationManager.modelName)
  }

  private func store(at storeURL: URL, isCompatibleWithModel model: NSManagedObjectModel) -> Bool {
    let storeMetadata = self.metadataForStoreAtURL(storeURL: storeURL)

    return model.isConfiguration(withName: nil, compatibleWithStoreMetadata: storeMetadata)
  }

  private func metadataForStoreAtURL(storeURL: URL) -> [String: Any] {
    let metadata: [String: Any]
    do {
      metadata = try NSPersistentStoreCoordinator
        .metadataForPersistentStore(ofType: NSSQLiteStoreType,
                                    at: storeURL, options: nil)
    } catch {
      metadata = [:]
      print("Error retrieving metadata for store at URL: \(storeURL): \(error)")
    }
    return metadata
  }

  private func migrateStoreAt(URL storeURL: URL,
                              fromModel from: NSManagedObjectModel,
                              toModel to: NSManagedObjectModel,
                              mappingModel: NSMappingModel? = nil) throws {
    let migrationManager = NSMigrationManager(sourceModel: from, destinationModel: to)

    let migrationMappingModel = try? mappingModel
    ?? NSMappingModel.inferredMappingModel(forSourceModel: from, destinationModel: to)

    let targetURL = storeURL.deletingLastPathComponent()
    let destinationName = storeURL.lastPathComponent + "~1"
    let destinationURL = targetURL.appendingPathComponent(destinationName)

    if FileManager.default.fileExists(atPath: destinationURL.path) {
      try? FileManager.default.removeItem(at: destinationURL)
    }

    Self.logger.trace("Migrating Core Data store")
    try migrationManager.migrateStore(from: storeURL,
                                      sourceType: NSSQLiteStoreType,
                                      options: nil,
                                      with: migrationMappingModel,
                                      toDestinationURL: destinationURL,
                                      destinationType: NSSQLiteStoreType,
                                      destinationOptions: nil)

    let fileManager = FileManager.default
    let wal = storeURL.lastPathComponent + "-wal"
    let shm = storeURL.lastPathComponent + "-shm"
    let destinationWal = targetURL
      .appendingPathComponent(wal)
    let destinationShm = targetURL
      .appendingPathComponent(shm)
    // cleanup in case
    try? fileManager.removeItem(at: destinationWal)
    try? fileManager.removeItem(at: destinationShm)

    Self.logger.trace("Deleting old Core Data store")
    try fileManager.removeItem(at: storeURL)
    Self.logger.trace("Moving into place the newly-migrated Core Data store")
    try fileManager.moveItem(at: destinationURL, to: storeURL)
  }

  public func cleanupStoreFile() {
    let storeURL = self.storeURL
    let fileManager = FileManager.default
    let wal = storeURL.appendingPathComponent("-wal")
    let shm = storeURL.appendingPathComponent("-shm")
    // cleanup in case
    try? fileManager.removeItem(at: wal)
    try? fileManager.removeItem(at: shm)
    try? fileManager.removeItem(at: storeURL)
  }

  public func canPeformMigration() -> Bool {
    return self.storeModel != nil
  }

  public func needsMigration() -> Bool {
    guard let storeModel = self.storeModel,
          let lastVersion = DBVersion.allCases.last else { return false }

    return storeModel != lastVersion.model()
  }

  public func performMigration() async throws {
    return try await withCheckedThrowingContinuation { continuation in
      do {
        try performMigration {
          continuation.resume()
        }
      } catch {
        continuation.resume(throwing: error)
      }
    }
  }

  public func performMigration(completionHandler: @escaping () -> Void) throws {
    guard let storeModel = self.storeModel,
          let currentVersion = DBVersion(model: storeModel),
          let nextVersion = currentVersion.next() else {
      completionHandler()
      return
    }

    let destinationModel = nextVersion.model()
    var mappingModel: NSMappingModel?

    if let mappingModelName = nextVersion.mappingModelName(),
       let mapPath = Bundle.main.path(forResource: mappingModelName, ofType: "cdm") {
      let mapUrl = URL(fileURLWithPath: mapPath)

      mappingModel = NSMappingModel(contentsOf: mapUrl)
    }

    try self.migrateStoreAt(URL: self.storeURL,
                            fromModel: storeModel,
                            toModel: destinationModel,
                            mappingModel: mappingModel)

    // update after migration
    self.storeModel = destinationModel

    // Only continue if there's extra work to be done
    guard currentVersion == .v8 else {
      completionHandler()
      return
    }

    let stack = self.getCoreDataStack()
    stack.loadStore { _, error in
      /// Only continue if there weren't any errors when loading the store
      guard error == nil else {
        completionHandler()
        return
      }

      let dataManager = DataManager(coreDataStack: stack)

      if currentVersion == .v8 {
        self.populateIsFinished(dataManager: dataManager)
        self.populateFolderDetails(dataManager: dataManager)
      }

      completionHandler()
    }
  }
}

extension NSManagedObjectModel {
  private class func modelURLs(in modelFolder: String) -> [URL] {
    return Bundle.main
      .urls(forResourcesWithExtension: "mom",
            subdirectory: "\(modelFolder).momd") ?? []
  }

  class func modelVersionsFor(modelNamed modelName: String) -> [NSManagedObjectModel] {
    return self.modelURLs(in: modelName)
      .compactMap(NSManagedObjectModel.init)
  }

  class func bookplayerModel(named modelName: String) -> NSManagedObjectModel {
    let model = self.modelURLs(in: "BookPlayer")
      .filter { $0.lastPathComponent == "\(modelName).mom" }
      .first
      .flatMap(NSManagedObjectModel.init)
    return model ?? NSManagedObjectModel()
  }

  class func model(named modelName: String, in bundle: Bundle = .main) -> NSManagedObjectModel {
    return bundle.url(forResource: modelName, withExtension: "momd")
      .flatMap(NSManagedObjectModel.init)
    ?? NSManagedObjectModel()
  }
}

func == (firstModel: NSManagedObjectModel,
         otherModel: NSManagedObjectModel) -> Bool {
  return firstModel.entitiesByName == otherModel.entitiesByName
}
