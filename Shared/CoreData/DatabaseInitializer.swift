//
//  DatabaseInitializer.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 30/9/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import CoreData
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

  /// Free space below which an error that doesn't say why a file failed is put down to a full disk.
  /// Generous on purpose: a wrong guess only asks the user to free up space and retry, while missing
  /// a full disk offers to restore or reset a library that's intact
  static let nearlyFullCapacity = 100 * 1024 * 1024

  /// Whether the store failed only because the device has no free space. It's intact then, so
  /// resetting it or restoring an older backup would lose data to a problem that clears by itself
  /// - Parameter availableCapacity: Free bytes on the database's volume. Without it, only errors
  ///   that name a lack of space count
  public static func isOutOfSpaceError(_ error: NSError, availableCapacity: Int? = nil) -> Bool {
    /// `SQLITE_FULL`
    let sqliteFull = 13

    switch (error.domain, error.code) {
    case (NSPOSIXErrorDomain, Int(ENOSPC)),
      (NSCocoaErrorDomain, NSFileWriteOutOfSpaceError),
      (NSSQLiteErrorDomain, sqliteFull):
      return true
    default:
      break
    }

    if error.userInfo[NSSQLiteErrorDomain] as? Int == sqliteFull {
      return true
    }

    /// Core Data fails to create a store's files with a generic write error, and only this text
    /// carries the errno (GH #1324)
    if let reason = error.userInfo["reason"] as? String, reason.hasSuffix("code = \(ENOSPC)") {
      return true
    }

    /// On a full device SQLite can fail to create the -shm, and reports only that it couldn't open
    /// the database, so the free space decides
    if isUnexplainedFileError(error),
      let availableCapacity,
      availableCapacity < nearlyFullCapacity
    {
      return true
    }

    if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
      return isOutOfSpaceError(underlyingError, availableCapacity: availableCapacity)
    }

    return false
  }

  /// Free bytes on the volume that holds the database
  public static func availableCapacityForDatabase() -> Int? {
    guard
      let containerURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: Constants.ApplicationGroupIdentifier
      )
    else { return nil }

    return try? containerURL.resourceValues(forKeys: [.volumeAvailableCapacityKey])
      .volumeAvailableCapacity
  }

  /// `SQLITE_CANTOPEN` and the `SQLITE_IOERR` family, which say a file failed but not why
  private static func isUnexplainedFileError(_ error: NSError) -> Bool {
    let sqliteCode =
      error.domain == NSSQLiteErrorDomain
      ? error.code
      : error.userInfo[NSSQLiteErrorDomain] as? Int

    guard let sqliteCode else { return false }

    // Extended result codes keep the primary code in the low byte
    let primaryCode = sqliteCode & 0xFF
    let sqliteIOError = 10
    let sqliteCantOpen = 14

    return primaryCode == sqliteIOError || primaryCode == sqliteCantOpen
  }

  /// Attempt to restore database from the latest backup
  /// - Throws: The error that stopped the restore
  public func restoreFromLatestBackup() async throws {
    // Get latest backup
    guard let backupURL = databaseBackupService.getLatestBackup() else {
      Self.logger.error("No backup available for restoration")
      throw BookPlayerError.runtimeError("No backup available for restoration")
    }

    Self.logger.info("Found backup to restore: \(backupURL.lastPathComponent)")

    // Restore database from backup
    try await databaseBackupService.restoreDatabase(from: backupURL)
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
    let stack = dataMigrationManager.getCoreDataStack()

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      stack.loadStore { _, error in
        if let error = error {
          Self.logger.error("Failed to load store")

          continuation.resume(throwing: error)
        } else {
          continuation.resume()
        }
      }
    }

    let dataManager = DataManager(coreDataStack: stack)
    let audioMetadataService = AudioMetadataService()
    let libraryService = LibraryService()
    libraryService.setup(dataManager: dataManager, audioMetadataService: audioMetadataService)
    // On the view context's queue: it's a main-queue context, and this runs on a background
    // thread. getLibrary fetches the library, and creates it on a first launch
    await dataManager.getContext().perform { _ = libraryService.getLibrary() }

    return stack
  }
}
