//
//  DataMigrationManager.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 19/2/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import CoreData
import Foundation

/// Simplified migration manager for iCloud-native design (fresh start, no legacy migrations needed)
public final class DataMigrationManager: BPLogger {
  private let modelName: String = "BookPlayer"
  private let currentModel: NSManagedObjectModel
  private let storeURL: URL

  public init() {
    self.currentModel = .model(named: self.modelName)
    let storeURL = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: Constants.ApplicationGroupIdentifier
    )!
    .appendingPathComponent("\(self.modelName).sqlite")
    self.storeURL = storeURL
  }

  public func getCoreDataStack() -> CoreDataStack {
    return CoreDataStack(modelName: self.modelName)
  }

  public func cleanupStoreFile() {
    let storeURL = self.storeURL
    let fileManager = FileManager.default
    try? fileManager.removeItem(at: storeURL)
  }

  /// Deletes associated WAL and SHM files for a given database URL
  public func cleanupAssociatedFiles() {
    let storeURL = self.storeURL
    let fileManager = FileManager.default
    let walURL = storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
    try? fileManager.removeItem(at: walURL)

    let shmURL = storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm")
    try? fileManager.removeItem(at: shmURL)
  }

  public func canPeformMigration() -> Bool {
    return true
  }

  public func needsMigration() -> Bool {
    return false  // No migrations needed for fresh iCloud-native design
  }

  public func performMigration() async throws {
    // No-op: fresh start design requires no migrations
  }

  public func performMigration(completionHandler: @escaping () -> Void) throws {
    // No-op: fresh start design requires no migrations
    completionHandler()
  }
}

extension NSManagedObjectModel {
  class func model(named modelName: String, in bundle: Bundle = .main) -> NSManagedObjectModel {
    return bundle.url(forResource: modelName, withExtension: "momd")
      .flatMap(NSManagedObjectModel.init)
      ?? NSManagedObjectModel()
  }
}

