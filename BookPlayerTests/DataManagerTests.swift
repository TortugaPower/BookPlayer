//
//  DataManagerTests.swift
//  BookPlayerTests
//
//  Created by Gianni Carlo on 5/18/18.
//  Copyright © 2018 BookPlayer LLC. All rights reserved.
//

@testable import BookPlayer
@testable import BookPlayerKit
import Combine
import CoreData
import XCTest

class DataManagerTests: XCTestCase {
  var dataManager: DataManager!

  override func setUp() {
    super.setUp()
    self.dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))
    // Put setup code here. This method is called before the invocation of each test method in the class.
    let documentsFolder = DataManager.getDocumentsFolderURL()
    DataTestUtils.clearFolderContents(url: documentsFolder)
    let processedFolder = DataManager.getProcessedFolderURL()
    DataTestUtils.clearFolderContents(url: processedFolder)
  }
}

// MARK: - processFiles()

class ProcessFilesTests: DataManagerTests {
  var importManager: ImportManager!
  var subscription: AnyCancellable?

  override func setUp() {
    self.subscription?.cancel()
    super.setUp()
  }

  func testProcessOneFile() {
    let filename = "file.txt"
    let bookContents = "bookcontents".data(using: .utf8)!
    let documentsFolder = DataManager.getDocumentsFolderURL()

    // Add test file to Documents folder
    let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: documentsFolder)

    let expectation = XCTestExpectation(description: "File import notification")

    let audioMetadataService = AudioMetadataService()
    let libraryService = LibraryService()
    libraryService.setup(dataManager: self.dataManager, audioMetadataService: audioMetadataService)
    self.importManager = ImportManager(libraryService: libraryService)

    self.subscription = self.importManager.observeFiles().sink { files in
      guard !files.isEmpty else { return }

      expectation.fulfill()
    }

    self.importManager.process(fileUrl)

    wait(for: [expectation], timeout: 15)
  }
}

/// Guards the v11→v12 manual migration: `shouldInferMappingModelAutomatically` is OFF,
/// so if the v12 `.xcdatamodel` is ever edited after `MappingModel_v11_to_v12` was
/// generated, the checksum mismatch makes `migrateStore` throw at launch for every
/// existing install. This must fail in CI first.
class MigrationV11ToV12Tests: XCTestCase {
  func testMappingModelMatchesModelsAndMigratesStore() throws {
    let v11 = DBVersion.v11.model()
    let v12 = DBVersion.v12.model()
    XCTAssertFalse(v11.entities.isEmpty, "v11 model failed to load from the bundle")
    XCTAssertFalse(v12.entities.isEmpty, "v12 model failed to load from the bundle")
    XCTAssertTrue(v12.entitiesByName.keys.contains("ExternalResource"))

    // The lookup validates BOTH sides' entity checksums — this is exactly what
    // breaks when a model is edited after its mapping model was generated
    let mapping = NSMappingModel(from: [Bundle.main], forSourceModel: v11, destinationModel: v12)
    let unwrappedMapping = try XCTUnwrap(mapping, "MappingModel_v11_to_v12 no longer matches the v11/v12 models")

    // End-to-end: run a real v11 store through the migration and verify the
    // result opens as a v12 store
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }
    let sourceURL = tempDir.appendingPathComponent("v11.sqlite")
    let destinationURL = tempDir.appendingPathComponent("v12.sqlite")

    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: v11)
    let store = try coordinator.addPersistentStore(
      ofType: NSSQLiteStoreType,
      configurationName: nil,
      at: sourceURL,
      options: nil
    )
    try coordinator.remove(store)

    let manager = NSMigrationManager(sourceModel: v11, destinationModel: v12)
    try manager.migrateStore(
      from: sourceURL,
      sourceType: NSSQLiteStoreType,
      options: nil,
      with: unwrappedMapping,
      toDestinationURL: destinationURL,
      destinationType: NSSQLiteStoreType,
      destinationOptions: nil
    )

    let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
      ofType: NSSQLiteStoreType,
      at: destinationURL,
      options: nil
    )
    XCTAssertTrue(
      v12.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata),
      "migrated store is not compatible with the v12 model"
    )
  }
}

// MARK: - Database recovery

class DatabaseRecoveryTests: XCTestCase {
  private var folder: URL!

  override func setUpWithError() throws {
    folder = FileManager.default.temporaryDirectory
      .appendingPathComponent("DatabaseRecoveryTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try FileManager.default.removeItem(at: folder)
  }

  private func write(_ content: String, to name: String) throws -> URL {
    let url = folder.appendingPathComponent(name)
    try Data(content.utf8).write(to: url)
    return url
  }

  func testOutOfSpaceErrorsAreRecognized() {
    let outOfSpace = [
      NSError(domain: NSPOSIXErrorDomain, code: Int(ENOSPC)),
      NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError),
      // GH #1324: what opening the store reported with no space left
      NSError(
        domain: NSCocoaErrorDomain,
        code: NSFileWriteUnknownError,
        userInfo: ["reason": "Failed to create file; code = 28"]
      ),
      NSError(domain: "NSSQLiteErrorDomain", code: 13),
      NSError(
        domain: NSCocoaErrorDomain,
        code: NSPersistentStoreSaveError,
        userInfo: ["NSSQLiteErrorDomain": 13]
      ),
      // A failed migration wraps the cause
      NSError(
        domain: NSCocoaErrorDomain,
        code: NSMigrationError,
        userInfo: [NSUnderlyingErrorKey: NSError(domain: NSPOSIXErrorDomain, code: Int(ENOSPC))]
      ),
    ]

    for error in outOfSpace {
      XCTAssertTrue(DatabaseInitializer.isOutOfSpaceError(error), "\(error)")
    }
  }

  func testOtherErrorsAreNotOutOfSpace() {
    let others = [
      NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES)),
      NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError),
      NSError(
        domain: NSCocoaErrorDomain,
        code: NSFileWriteUnknownError,
        userInfo: ["reason": "Failed to create file; code = 13"]
      ),
      // SQLITE_CORRUPT
      NSError(domain: "NSSQLiteErrorDomain", code: 11),
      NSError(domain: NSCocoaErrorDomain, code: NSMigrationError),
    ]

    for error in others {
      XCTAssertFalse(DatabaseInitializer.isOutOfSpaceError(error), "\(error)")
    }
  }

  /// A -wal left beside a fresh store belongs to the database that was reset
  func testCleanupRemovesTheStoreAndItsJournalFiles() throws {
    let storeURL = try write("store", to: "BookPlayer.sqlite")
    let wal = try write("wal", to: "BookPlayer.sqlite-wal")
    let shm = try write("shm", to: "BookPlayer.sqlite-shm")

    DataMigrationManager(storeURL: storeURL).cleanupStoreFile()

    for url in [storeURL, wal, shm] {
      XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), url.lastPathComponent)
    }
  }

  /// GH #1541: a backup that can't be restored must not cost the library it was meant to replace
  func testAFailedRestoreKeepsTheCurrentDatabase() async throws {
    let databaseURL = try write("current library", to: "BookPlayer.sqlite")
    let walURL = try write("recent changes", to: "BookPlayer.sqlite-wal")
    let backupURL = try write("not a database", to: "backup.sqlite")

    do {
      try await DatabaseBackupService(databaseURL: databaseURL).restoreDatabase(from: backupURL)
      XCTFail("A file that isn't a database can't be restored")
    } catch {
      // A bad backup still leads to the recovery options, not to the disk-full alert
      XCTAssertFalse(DatabaseInitializer.isOutOfSpaceError(error as NSError), "\(error)")
    }

    XCTAssertEqual(try String(contentsOf: databaseURL, encoding: .utf8), "current library")
    XCTAssertEqual(try String(contentsOf: walURL, encoding: .utf8), "recent changes")
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path).count, 3)
  }

  /// A restore the file system stops reports why, so a full disk isn't taken for a bad backup and
  /// answered with a reset
  func testARestoreThatCantBeCopiedReportsTheFileError() async throws {
    let databaseURL = try write("current library", to: "BookPlayer.sqlite")
    let backupFolder = folder.appendingPathComponent("Backups")
    try FileManager.default.createDirectory(at: backupFolder, withIntermediateDirectories: true)
    let backupURL = backupFolder.appendingPathComponent("backup.sqlite")
    try Data("backup".utf8).write(to: backupURL)

    // Nothing new can be written beside the database
    try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: folder.path)
    defer {
      try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.path)
    }

    do {
      try await DatabaseBackupService(databaseURL: databaseURL).restoreDatabase(from: backupURL)
      XCTFail("The backup can't be copied into a read-only folder")
    } catch {
      let error = error as NSError
      XCTAssertEqual(error.domain, NSCocoaErrorDomain, "\(error)")
      XCTAssertEqual(error.code, NSFileWriteNoPermissionError, "\(error)")
    }

    XCTAssertEqual(try String(contentsOf: databaseURL, encoding: .utf8), "current library")
  }

  func testARestoreReplacesTheDatabaseWithTheBackup() async throws {
    let databaseURL = folder.appendingPathComponent("BookPlayer.sqlite")
    let backupURL = folder.appendingPathComponent("backup.sqlite")
    let backupStack = CoreDataStack(testPath: backupURL.path)
    _ = backupStack.managedContext
    let staleWal = try write("stale", to: "BookPlayer.sqlite-wal")
    try Data("current library".utf8).write(to: databaseURL)

    try await DatabaseBackupService(databaseURL: databaseURL).restoreDatabase(from: backupURL)

    XCTAssertNotEqual(try Data(contentsOf: databaseURL), Data("current library".utf8))
    XCTAssertNotEqual(try? Data(contentsOf: staleWal), Data("stale".utf8))
    XCTAssertTrue(
      try NSPersistentStoreCoordinator.metadataForPersistentStore(
        ofType: NSSQLiteStoreType,
        at: databaseURL,
        options: nil
      ).isEmpty == false
    )
  }
}
