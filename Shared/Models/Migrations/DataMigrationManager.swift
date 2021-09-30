//
//  DataMigrationManager.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 19/2/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import CoreData
import Foundation
import UIKit

public final class DataMigrationManager {
  private let modelName: String
  private let currentModel: NSManagedObjectModel
  private let storeURL: URL
  private var storeModel: NSManagedObjectModel?

  public init(modelNamed: String) {
    self.modelName = modelNamed
    self.currentModel = .model(named: modelNamed)
    let storeURL =  FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: Constants.ApplicationGroupIdentifier)!
      .appendingPathComponent("BookPlayer.sqlite")
    self.storeURL = storeURL
    self.storeModel = NSManagedObjectModel.modelVersionsFor(modelNamed: self.modelName)
      .filter {
        self.store(at: storeURL, isCompatibleWithModel: $0)
      }.first
  }

  public func getCoreDataStack() -> CoreDataStack {
    return CoreDataStack(modelName: self.modelName)
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

    try fileManager.removeItem(at: storeURL)
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

  public func performMigration(completionHandler: @escaping (Error?) -> Void) throws {
    guard let storeModel = self.storeModel,
          let currentVersion = DBVersion(model: storeModel),
          let nextVersion = currentVersion.next() else {
            completionHandler(nil)
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
    guard currentVersion == .v3 || currentVersion == .v5 else {
      completionHandler(nil)
      return
    }

    let stack = self.getCoreDataStack()
    stack.loadStore { _, error in
      if let error = error {
        completionHandler(error)
        return
      }

      let dataManager = DataManager(coreDataStack: stack)

      // Extra data migration
      if currentVersion == .v3 {
        // Migrate folder hierarchy
        self.migrateFolderHierarchy(dataManager: dataManager)
        // Migrate books names
        self.migrateBooks(dataManager: dataManager)
      }

      if currentVersion == .v5 {
        self.migrateLibraryOrder(dataManager: dataManager)
      }

      completionHandler(nil)
    }
  }

  public func setupDefaultState() {
    let userDefaults = UserDefaults(suiteName: Constants.ApplicationGroupIdentifier)

    // Migrate user defaults app icon
    if userDefaults?
        .string(forKey: Constants.UserDefaults.appIcon.rawValue) == nil {
      let storedIconId = UserDefaults.standard.string(forKey: Constants.UserDefaults.appIcon.rawValue)
      userDefaults?.set(storedIconId, forKey: Constants.UserDefaults.appIcon.rawValue)
    } else if let sharedAppIcon = userDefaults?
                .string(forKey: Constants.UserDefaults.appIcon.rawValue),
              let localAppIcon = UserDefaults.standard.string(forKey: Constants.UserDefaults.appIcon.rawValue),
              sharedAppIcon != localAppIcon {
      userDefaults?.set(localAppIcon, forKey: Constants.UserDefaults.appIcon.rawValue)
      UserDefaults.standard.removeObject(forKey: Constants.UserDefaults.appIcon.rawValue)
    }

    // Migrate protection for Processed folder
    if !(userDefaults?
        .bool(forKey: Constants.UserDefaults.fileProtectionMigration.rawValue) ?? false) {
      DataManager.getProcessedFolderURL().disableFileProtection()
      userDefaults?.set(true, forKey: Constants.UserDefaults.fileProtectionMigration.rawValue)
    }

    // Exclude Processed folder from phone backups
    var resourceValues = URLResourceValues()
    resourceValues.isExcludedFromBackup = true
    var processedFolderURL = DataManager.getProcessedFolderURL()

    try? processedFolderURL.setResourceValues(resourceValues)

    // Set system theme as default
    if UserDefaults.standard.object(forKey: Constants.UserDefaults.systemThemeVariantEnabled.rawValue) == nil {
      UserDefaults.standard.set(true, forKey: Constants.UserDefaults.systemThemeVariantEnabled.rawValue)
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
