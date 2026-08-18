//
//  DatabaseInitializer.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 30/9/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import Foundation

/// Simplified initializer for iCloud-native design (no migrations or backups needed for fresh start)
public class DatabaseInitializer: BPLogger {
  private let dataMigrationManager: DataMigrationManager

  /// Initializer
  public init() {
    self.dataMigrationManager = DataMigrationManager()
  }

  /// Load CoreData stack (no migrations needed for fresh iCloud-native design)
  public func loadCoreDataStack() async throws -> CoreDataStack {
    return try await loadLibrary()
  }

  /// Wrapper to clean up the DB related files
  public func cleanupStoreFiles() {
    dataMigrationManager.cleanupStoreFile()
  }

  /// Wrapper to clean up the DB associated files
  public func cleanupAssociatedFiles() {
    dataMigrationManager.cleanupAssociatedFiles()
  }

  /// No backups available for fresh iCloud-native design
  public func hasAvailableBackups() -> Bool {
    return false
  }

  /// No backup restoration needed
  public func restoreFromLatestBackup() async -> Bool {
    return false
  }

  private func loadLibrary() async throws -> CoreDataStack {
    return try await withCheckedThrowingContinuation { continuation in
      let stack = dataMigrationManager.getCoreDataStack()

      stack.loadStore { _, error in
        if let error = error {
          Self.logger.error("Failed to load store")
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: stack)
        }
      }
    }
  }
}
