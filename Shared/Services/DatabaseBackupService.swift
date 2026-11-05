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
  private let databaseURL: URL?

  // MARK: - Public API

  public init(databaseURL: URL? = nil) {
    self.databaseURL = databaseURL
  }

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
    guard (try? copyDatabaseFiles(from: sourceURL, to: backupURL)) != nil else {
      Self.logger.error("Failed to copy database files")
      return
    }

    // Validate backup can be loaded by CoreData
    guard (try? validateBackup(at: backupURL)) != nil else {
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
  /// - Throws: The error that stopped the restore, so a full disk can be told apart from a bad backup
  public func restoreDatabase(from backupURL: URL) async throws {
    Self.logger.info("Starting database restoration from: \(backupURL.lastPathComponent)")

    // Verify backup file exists
    guard fileManager.fileExists(atPath: backupURL.path) else {
      Self.logger.error("Backup file does not exist at: \(backupURL.path)")
      throw BookPlayerError.runtimeError("Backup file does not exist")
    }

    // Get destination (main database) URL
    guard let destinationURL = getSourceDatabaseURL() else {
      Self.logger.error("Failed to get destination database URL")
      throw BookPlayerError.runtimeError("Failed to get destination database URL")
    }

    // Prepared beside the database, which isn't touched until there's a valid copy to replace it
    let stagingURL = destinationURL.deletingLastPathComponent()
      .appendingPathComponent("BookPlayer-restoring.sqlite")
    deleteDatabaseFiles(at: stagingURL)

    do {
      try copyDatabaseFiles(from: backupURL, to: stagingURL)
      try validateBackup(at: stagingURL)
      // As a single file it replaces the database in one step, so an interruption can't leave
      // no database, or the restored one without its WAL
      try mergeWriteAheadLog(of: stagingURL)
    } catch {
      Self.logger.error(
        "Restoration stopped before replacing the database, cleaning up: \(error.localizedDescription)"
      )
      deleteDatabaseFiles(at: stagingURL)
      throw error
    }

    do {
      // These belong to the database being replaced, and SQLite would apply them to the restored one
      try removeJournalFiles(of: destinationURL)
      try replaceDatabaseFile(at: destinationURL, with: stagingURL)
    } catch {
      Self.logger.error("Failed to move restored database into place: \(error.localizedDescription)")
      deleteDatabaseFiles(at: stagingURL)
      throw error
    }

    Self.logger.info("Database restoration completed successfully")
  }

  // MARK: - Private Methods

  /// Returns the URL of the source CoreData database file
  private func getSourceDatabaseURL() -> URL? {
    if let databaseURL { return databaseURL }

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
  private func copyDatabaseFiles(from sourceURL: URL, to destinationURL: URL) throws {
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
    } catch {
      Self.logger.error("Failed to copy database files: \(error.localizedDescription)")
      throw error
    }
  }

  /// Moves a single-file database over another with one rename, which replaces it atomically
  private func replaceDatabaseFile(at destinationURL: URL, with sourceURL: URL) throws {
    guard rename(sourceURL.path, destinationURL.path) == 0 else {
      let code = errno
      throw NSError(
        domain: NSPOSIXErrorDomain,
        code: Int(code),
        userInfo: [NSFilePathErrorKey: destinationURL.path]
      )
    }
  }

  /// Returns the app's managed object model
  private func loadManagedObjectModel() throws -> NSManagedObjectModel {
    guard let modelURL = Bundle.main.url(forResource: "BookPlayer", withExtension: "momd"),
      let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL)
    else {
      Self.logger.error("Failed to load managed object model")
      throw BookPlayerError.runtimeError("Failed to load managed object model")
    }

    return managedObjectModel
  }

  /// Writes a database's WAL into its main file by switching it to a rollback journal, leaving it as
  /// a single file. Core Data switches it back to WAL the next time it opens the store
  private func mergeWriteAheadLog(of databaseURL: URL) throws {
    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: try loadManagedObjectModel())
    let store = try coordinator.addPersistentStore(
      ofType: NSSQLiteStoreType,
      configurationName: nil,
      at: databaseURL,
      options: [
        NSMigratePersistentStoresAutomaticallyOption: false,
        NSInferMappingModelAutomaticallyOption: false,
        NSSQLitePragmasOption: ["journal_mode": "DELETE"],
      ]
    )
    try coordinator.remove(store)

    let walURL = databaseURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
    let walSize = (try? walURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
    guard walSize == 0 else {
      throw BookPlayerError.runtimeError("The WAL of \(databaseURL.lastPathComponent) wasn't merged")
    }

    try removeJournalFiles(of: databaseURL)
  }

  /// Validates that the backup can be loaded by CoreData without errors
  /// Uses a read-only check without applying migrations for speed
  private func validateBackup(at backupURL: URL) throws {
    // Create a persistent store coordinator for validation
    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: try loadManagedObjectModel())

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
    } catch {
      Self.logger.error("Backup validation failed: \(error.localizedDescription)")
      throw error
    }
  }

  /// Deletes a database and its associated WAL and SHM files
  private func deleteDatabaseFiles(at databaseURL: URL) {
    try? fileManager.removeItem(at: databaseURL)
    deleteAssociatedFiles(for: databaseURL)
  }

  /// Deletes associated WAL and SHM files for a given database URL
  private func deleteAssociatedFiles(for databaseURL: URL) {
    let walURL = databaseURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
    try? fileManager.removeItem(at: walURL)

    let shmURL = databaseURL.deletingPathExtension().appendingPathExtension("sqlite-shm")
    try? fileManager.removeItem(at: shmURL)
  }

  /// Deletes a database's WAL and SHM files, failing if one can't be removed
  private func removeJournalFiles(of databaseURL: URL) throws {
    for pathExtension in ["sqlite-wal", "sqlite-shm"] {
      let url = databaseURL.deletingPathExtension().appendingPathExtension(pathExtension)
      if fileManager.fileExists(atPath: url.path) {
        try fileManager.removeItem(at: url)
      }
    }
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
