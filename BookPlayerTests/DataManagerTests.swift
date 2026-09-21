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
