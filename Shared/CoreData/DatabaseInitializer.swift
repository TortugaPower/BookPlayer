//
//  DatabaseInitializer.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 30/9/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import Foundation

/// Wrapper for `DataMigrationManager` to simplify handling all the migrations
public class DatabaseInitializer: BPLogger {
  private let dataMigrationManager: DataMigrationManager
  private let databaseBackupService: DatabaseBackupService

  /// Initializer
  public init() {
    self.dataMigrationManager = DataMigrationManager()
    self.databaseBackupService = DatabaseBackupService()
  }

  /// Handle applying all the migrations to the CoreData stack before returning it
  public func loadCoreDataStack() async throws -> CoreDataStack {
    if dataMigrationManager.canPeformMigration() {
      return try await handleMigrations()
    } else {
      return try await loadLibrary()
    }
  }

  /// Wrapper to clean up the DB related files
  /// - Note: Only necessary if we're attempting to recover from a failed migration
  public func cleanupStoreFiles() {
    dataMigrationManager.cleanupStoreFile()
  }

  /// Wrapper to clean up the DB associated files
  public func cleanupAssociatedFiles() {
    dataMigrationManager.cleanupAssociatedFiles()
  }

  /// Check if local database backups are available
  /// - Returns: true if at least one backup exists
  public func hasAvailableBackups() -> Bool {
    return databaseBackupService.getLatestBackup() != nil
  }

  /// Attempt to restore database from the latest backup
  /// - Returns: true if restoration succeeded and database loaded successfully
  public func restoreFromLatestBackup() async -> Bool {
    // Get latest backup
    guard let backupURL = databaseBackupService.getLatestBackup() else {
      Self.logger.error("No backup available for restoration")
      return false
    }
    
    Self.logger.info("Found backup to restore: \(backupURL.lastPathComponent)")
    
    // Restore database from backup
    return await databaseBackupService.restoreDatabase(from: backupURL)
  }

  private func handleMigrations() async throws -> CoreDataStack {
    if dataMigrationManager.needsMigration() {
      try await dataMigrationManager.performMigration()
      return try await handleMigrations()
    } else {
      return try await loadLibrary()
    }
  }

  private func loadLibrary() async throws -> CoreDataStack {
    return try await withCheckedThrowingContinuation { continuation in
      let stack = dataMigrationManager.getCoreDataStack()

      stack.loadStore { _, error in
        if let error = error {
          Self.logger.error("Failed to load store")

          continuation.resume(throwing: error)
        } else {
          let dataManager = DataManager(coreDataStack: stack)
          let audioMetadataService = AudioMetadataService()
          let libraryService = LibraryService()
          libraryService.setup(dataManager: dataManager, audioMetadataService: audioMetadataService)
          _ = libraryService.getLibrary()

          continuation.resume(returning: stack)
        }
      }
    }
  }
}
