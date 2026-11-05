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

  /// What opening the store reported on a full disk when SQLite couldn't create the -shm: it says
  /// the file couldn't be opened, not why, so the free space decides
  func testAnUnexplainedOpenFailureIsOutOfSpaceOnlyOnANearlyFullDisk() {
    let cantOpen = NSError(
      domain: NSCocoaErrorDomain,
      code: NSFileReadUnknownError,
      userInfo: ["NSSQLiteErrorDomain": 14]
    )
    // SQLITE_IOERR_SHMSIZE, an extended code of SQLITE_IOERR
    let shmSizeError = NSError(domain: "NSSQLiteErrorDomain", code: 4874)
    let wrapped = NSError(
      domain: NSCocoaErrorDomain,
      code: NSMigrationError,
      userInfo: [NSUnderlyingErrorKey: cantOpen]
    )
    let nearlyFull = DatabaseInitializer.nearlyFullCapacity - 1
    let plentyOfSpace = 10 * 1024 * 1024 * 1024

    for error in [cantOpen, shmSizeError, wrapped] {
      XCTAssertTrue(DatabaseInitializer.isOutOfSpaceError(error, availableCapacity: 0), "\(error)")
      XCTAssertTrue(
        DatabaseInitializer.isOutOfSpaceError(error, availableCapacity: nearlyFull),
        "\(error)"
      )
      XCTAssertFalse(
        DatabaseInitializer.isOutOfSpaceError(error, availableCapacity: plentyOfSpace),
        "\(error)"
      )
      XCTAssertFalse(DatabaseInitializer.isOutOfSpaceError(error), "\(error)")
    }

    // A corrupt database isn't explained by a full disk
    let corrupt = NSError(
      domain: NSCocoaErrorDomain,
      code: NSFileReadCorruptFileError,
      userInfo: ["NSSQLiteErrorDomain": 11]
    )
    XCTAssertFalse(DatabaseInitializer.isOutOfSpaceError(corrupt, availableCapacity: 0))
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
      // SQLite rejected the file itself (SQLITE_NOTADB), and even on a full disk that leads to the
      // recovery options rather than the disk-full alert
      let error = error as NSError
      let sqliteCode =
        error.domain == NSSQLiteErrorDomain
        ? error.code
        : error.userInfo[NSSQLiteErrorDomain] as? Int
      XCTAssertEqual(sqliteCode, 26, "\(error)")
      XCTAssertFalse(DatabaseInitializer.isOutOfSpaceError(error, availableCapacity: 0), "\(error)")
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

  /// A backup's latest changes are only in its -wal until SQLite checkpoints them, so the restore
  /// has to merge that file into the database it puts in place
  @MainActor
  func testARestoreReplacesTheDatabaseWithTheBackup() async throws {
    let databaseURL = try write("current library", to: "BookPlayer.sqlite")
    let restoredWal = try write("stale", to: "BookPlayer.sqlite-wal")

    let backupURL = folder.appendingPathComponent("backup.sqlite")
    let backupStack = CoreDataStack(testPath: backupURL.path)
    let account = NSEntityDescription.insertNewObject(
      forEntityName: "Account",
      into: backupStack.managedContext
    )
    account.setValue("saved-in-the-backup", forKey: "id")
    account.setValue("", forKey: "email")
    account.setValue(false, forKey: "donationMade")
    account.setValue(false, forKey: "hasSubscription")
    try backupStack.managedContext.save()

    // The backup stays open, so nothing has checkpointed the record out of its -wal
    let backupWal = folder.appendingPathComponent("backup.sqlite-wal")
    XCTAssertGreaterThan(try Data(contentsOf: backupWal).count, 0)
    let backupID = try XCTUnwrap(storeUUID(at: backupURL))

    try await DatabaseBackupService(databaseURL: databaseURL).restoreDatabase(from: backupURL)

    // A single file: the stale -wal is gone and nothing is left of the copy it was prepared in
    XCTAssertEqual(
      try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted(),
      ["BookPlayer.sqlite", "backup.sqlite", "backup.sqlite-shm", "backup.sqlite-wal"]
    )
    XCTAssertEqual(try storeUUID(at: databaseURL), backupID)

    let restoredStack = CoreDataStack(testPath: databaseURL.path)
    let accountIDs = try restoredStack.managedContext
      .fetch(NSFetchRequest<NSManagedObject>(entityName: "Account"))
      .compactMap { $0.value(forKey: "id") as? String }
    XCTAssertEqual(accountIDs, ["saved-in-the-backup"])
    // Opening it puts it back in WAL mode
    XCTAssertTrue(FileManager.default.fileExists(atPath: restoredWal.path))

    withExtendedLifetime(backupStack) {}
  }

  private func storeUUID(at url: URL) throws -> String? {
    try NSPersistentStoreCoordinator.metadataForPersistentStore(
      ofType: NSSQLiteStoreType,
      at: url,
      options: nil
    )[NSStoreUUIDKey] as? String
  }
}

// MARK: - Database load errors

class DataInitializerCoordinatorTests: XCTestCase {
  private final class AlertPresenterSpy: AlertPresenter {
    var alerts = [BPAlertContent]()
    var simpleAlertCount = 0
    var onAlert: (() -> Void)?

    func showAlert(_ title: String?, message: String?, completion: (() -> Void)?) {
      simpleAlertCount += 1
    }

    func showAlert(_ content: BPAlertContent) {
      alerts.append(content)
      onAlert?()
    }

    func showLoader() {}
    func stopLoader() {}
  }

  /// Stands in for the database layer: a backup is always available, and restoring it fails as told
  private final class DatabaseInitializerStub: DatabaseInitializer {
    var restoreError: Error?

    override func hasAvailableBackups() -> Bool { true }

    override func restoreFromLatestBackup() async throws {
      if let restoreError { throw restoreError }
    }
  }

  private let corruptStore = NSError(domain: NSCocoaErrorDomain, code: NSFileReadCorruptFileError)
  private let plentyOfSpace = 10 * 1024 * 1024 * 1024

  /// Taps the first action of the latest alert and waits for the alert it leads to
  @MainActor
  private func tapFirstAction(on presenter: AlertPresenterSpy) async {
    let nextAlert = expectation(description: "next alert")
    presenter.onAlert = { nextAlert.fulfill() }
    presenter.alerts.last?.actionItems.first?.handler()
    await fulfillment(of: [nextAlert], timeout: 5)
    presenter.onAlert = nil
  }

  /// A restore stopped by a full disk leaves the library in place: it's answered with Retry, and if the
  /// library still fails to load afterwards the backup is offered again rather than the reset
  @MainActor
  func testARestoreStoppedByAFullDiskOffersRetryAndThenTheBackupAgain() async {
    let presenter = AlertPresenterSpy()
    let databaseInitializer = DatabaseInitializerStub()
    databaseInitializer.restoreError = NSError(
      domain: NSCocoaErrorDomain,
      code: NSFileWriteOutOfSpaceError
    )
    let coordinator = DataInitializerCoordinator(
      alertPresenter: presenter,
      databaseInitializer: databaseInitializer,
      availableCapacity: { self.plentyOfSpace }
    )

    await coordinator.handleError(corruptStore)
    XCTAssertEqual(presenter.alerts.last?.message, "database_backup_available_message".localized)

    await tapFirstAction(on: presenter)
    XCTAssertEqual(presenter.alerts.last?.message, "coredata_error_diskfull_description".localized)
    XCTAssertEqual(
      presenter.alerts.last?.actionItems.map(\.title),
      ["integration_retry_button".localized]
    )

    await coordinator.handleError(corruptStore)
    XCTAssertEqual(presenter.alerts.last?.message, "database_backup_available_message".localized)
    XCTAssertEqual(presenter.alerts.count, 3)
  }

  /// Any other restore failure still ends in the recovery options
  @MainActor
  func testARestoreThatFailsForAnotherReasonOffersTheReset() async {
    let presenter = AlertPresenterSpy()
    let databaseInitializer = DatabaseInitializerStub()
    databaseInitializer.restoreError = BookPlayerError.runtimeError("Not a database")
    let coordinator = DataInitializerCoordinator(
      alertPresenter: presenter,
      databaseInitializer: databaseInitializer,
      availableCapacity: { self.plentyOfSpace }
    )

    await coordinator.handleError(corruptStore)
    await tapFirstAction(on: presenter)

    XCTAssertEqual(presenter.alerts.count, 2)
    XCTAssertEqual(
      presenter.alerts.last?.message?.hasPrefix("database_restore_failed_message".localized),
      true
    )
    XCTAssertEqual(
      presenter.alerts.last?.actionItems.map(\.title),
      ["database_reset_button".localized, "cancel_button".localized]
    )
  }

  /// GH #1324: with no free space the library can only be loaded again, never reset, and the alert
  /// mustn't leave the app stuck on the loading screen
  @MainActor
  func testOutOfSpaceOffersARetryAndNothingElse() async {
    let presenter = AlertPresenterSpy()
    let coordinator = DataInitializerCoordinator(alertPresenter: presenter)

    await coordinator.handleError(
      NSError(
        domain: NSCocoaErrorDomain,
        code: NSFileWriteUnknownError,
        userInfo: ["reason": "Failed to create file; code = 28"]
      )
    )

    XCTAssertEqual(presenter.simpleAlertCount, 0)
    XCTAssertEqual(presenter.alerts.count, 1)
    XCTAssertEqual(presenter.alerts.first?.message, "coredata_error_diskfull_description".localized)
    XCTAssertEqual(
      presenter.alerts.first?.actionItems.map(\.title),
      ["integration_retry_button".localized]
    )
  }
}
