//
//  DatabaseBackupService.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 13/10/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import CoreData
import Foundation

/// Service responsible for creating, validating, and managing database backups
public class DatabaseBackupService: BPLogger {

  // MARK: - Properties

  private let fileManager = FileManager.default
  private let backupRetentionCount = 2

  // MARK: - Public API

  public init() {}

  /// Performs a complete backup operation: copy, validate, and cleanup
  public func performBackup() async {
    Self.logger.info("Starting daily database backup")

    // Get source and destination paths
    guard let sourceURL = getSourceDatabaseURL() else {
      Self.logger.error("Failed to get source database URL")
      return
    }

    let backupURL = createBackupURL()

    // Copy database files (.sqlite, .sqlite-wal, .sqlite-shm)
    guard copyDatabaseFiles(from: sourceURL, to: backupURL) else {
      Self.logger.error("Failed to copy database files")
      return
    }

    // Validate backup can be loaded by CoreData
    guard validateBackup(at: backupURL) else {
      Self.logger.error("Backup validation failed, deleting invalid backup")
      try? fileManager.removeItem(at: backupURL)
      // Also try to remove associated WAL/SHM files if they exist
      deleteAssociatedFiles(for: backupURL)
      return
    }

    // Cleanup old backups (keep last 2 only)
    cleanupOldBackups(keeping: backupRetentionCount)

    Self.logger.info("Database backup completed successfully at: \(backupURL.path)")
  }

  /// Get list of available backups sorted by creation date (newest first)
  /// - Returns: Array of backup file URLs
  public func getAvailableBackups() -> [URL] {
    let backupFolder = DataManager.getDatabaseBackupFolderURL()

    do {
      let files = try fileManager.contentsOfDirectory(
        at: backupFolder,
        includingPropertiesForKeys: [.creationDateKey],
        options: .skipsHiddenFiles
      )

      // Filter to only .sqlite files and sort by creation date (newest first)
      let backups = files
        .filter { $0.pathExtension == "sqlite" }
        .sorted { url1, url2 in
          let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
          let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
          return date1 > date2
        }

      return backups
    } catch {
      Self.logger.error("Failed to list backups: \(error.localizedDescription)")
      return []
    }
  }

  /// Get the most recent backup URL
  /// - Returns: URL of the latest backup, or nil if no backups exist
  public func getLatestBackup() -> URL? {
    return getAvailableBackups().first
  }

  /// Restore database from backup
  /// - Parameter backupURL: The backup file to restore from
  /// - Returns: true if restoration succeeded, false otherwise
  public func restoreDatabase(from backupURL: URL) async -> Bool {
    Self.logger.info("Starting database restoration from: \(backupURL.lastPathComponent)")

    // Verify backup file exists
    guard fileManager.fileExists(atPath: backupURL.path) else {
      Self.logger.error("Backup file does not exist at: \(backupURL.path)")
      return false
    }

    // Get destination (main database) URL
    guard let destinationURL = getSourceDatabaseURL() else {
      Self.logger.error("Failed to get destination database URL")
      return false
    }

    try? fileManager.removeItem(at: destinationURL)
    deleteAssociatedFiles(for: destinationURL)

    guard copyDatabaseFiles(from: backupURL, to: destinationURL) else {
      Self.logger.error("Failed to copy backup files during restoration")
      return false
    }

    guard validateBackup(at: destinationURL) else {
      Self.logger.error("Restored database validation failed, cleaning up")
      try? fileManager.removeItem(at: destinationURL)
      deleteAssociatedFiles(for: destinationURL)
      return false
    }

    Self.logger.info("Database restoration completed successfully")
    return true
  }

  // MARK: - Private Methods

  /// Returns the URL of the source CoreData database file
  private func getSourceDatabaseURL() -> URL? {
    guard
      let containerURL = fileManager.containerURL(
        forSecurityApplicationGroupIdentifier: Constants.ApplicationGroupIdentifier
      )
    else {
      Self.logger.error("Failed to get App Group container URL")
      return nil
    }

    return containerURL.appendingPathComponent("BookPlayer.sqlite")
  }

  /// Creates a timestamped backup URL in the ApplicationSupport/DatabaseBackups folder
  private func createBackupURL() -> URL {
    let dateFormatter = ISO8601DateFormatter()
    dateFormatter.formatOptions = [.withYear, .withMonth, .withDay, .withTime]
    let timestamp = dateFormatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
    let filename = "BookPlayer-\(timestamp).sqlite"

    return DataManager.getDatabaseBackupFolderURL()
      .appendingPathComponent(filename)
  }

  /// Copies the database files (including WAL and SHM) from source to destination
  private func copyDatabaseFiles(from sourceURL: URL, to destinationURL: URL) -> Bool {
    do {
      // Copy main .sqlite file
      try fileManager.copyItem(at: sourceURL, to: destinationURL)

      // Copy WAL file if it exists
      let walSource = sourceURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
      if fileManager.fileExists(atPath: walSource.path) {
        let walDestination = destinationURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
        try? fileManager.copyItem(at: walSource, to: walDestination)
      }

      // Copy SHM file if it exists
      let shmSource = sourceURL.deletingPathExtension().appendingPathExtension("sqlite-shm")
      if fileManager.fileExists(atPath: shmSource.path) {
        let shmDestination = destinationURL.deletingPathExtension().appendingPathExtension("sqlite-shm")
        try? fileManager.copyItem(at: shmSource, to: shmDestination)
      }

      return true
    } catch {
      Self.logger.error("Failed to copy database files: \(error.localizedDescription)")
      return false
    }
  }

  /// Validates that the backup can be loaded by CoreData without errors
  /// Uses a read-only check without applying migrations for speed
  private func validateBackup(at backupURL: URL) -> Bool {
    // Get the managed object model
    guard let modelURL = Bundle.main.url(forResource: "BookPlayer", withExtension: "momd"),
      let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL)
    else {
      Self.logger.error("Failed to load managed object model")
      return false
    }

    // Create a persistent store coordinator for validation
    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)

    do {
      // Attempt to add the store with read-only access
      // This validates that the file is readable and compatible with the schema
      let store = try coordinator.addPersistentStore(
        ofType: NSSQLiteStoreType,
        configurationName: nil,
        at: backupURL,
        options: [
          NSMigratePersistentStoresAutomaticallyOption: false,
          NSInferMappingModelAutomaticallyOption: false,
          NSReadOnlyPersistentStoreOption: true,
        ]
      )

      // Successfully opened the store, now close it
      try coordinator.remove(store)

      Self.logger.info("Backup validation successful")
      return true

    } catch {
      Self.logger.error("Backup validation failed: \(error.localizedDescription)")
      return false
    }
  }

  /// Deletes associated WAL and SHM files for a given database URL
  private func deleteAssociatedFiles(for databaseURL: URL) {
    let walURL = databaseURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
    try? fileManager.removeItem(at: walURL)

    let shmURL = databaseURL.deletingPathExtension().appendingPathExtension("sqlite-shm")
    try? fileManager.removeItem(at: shmURL)
  }

  /// Removes old backup files, keeping only the most recent ones
  /// - Parameter count: Number of backups to retain
  private func cleanupOldBackups(keeping count: Int) {
    let backupFolder = DataManager.getDatabaseBackupFolderURL()

    do {
      let files = try fileManager.contentsOfDirectory(
        at: backupFolder,
        includingPropertiesForKeys: [.creationDateKey],
        options: .skipsHiddenFiles
      )

      // Filter to only .sqlite files and sort by creation date (newest first)
      let backups =
        files
        .filter { $0.pathExtension == "sqlite" }
        .sorted { url1, url2 in
          let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
          let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
          return date1 > date2
        }

      // Delete all but the last 'count' backups
      let backupsToDelete = backups.dropFirst(count)

      for backup in backupsToDelete {
        Self.logger.info("Deleting old backup: \(backup.lastPathComponent)")
        try? fileManager.removeItem(at: backup)

        // Also delete associated WAL/SHM files
        deleteAssociatedFiles(for: backup)
      }

      if !backupsToDelete.isEmpty {
        Self.logger.info("Cleaned up \(backupsToDelete.count) old backup(s)")
      }

    } catch {
      Self.logger.error("Failed to cleanup old backups: \(error.localizedDescription)")
    }
  }
}
