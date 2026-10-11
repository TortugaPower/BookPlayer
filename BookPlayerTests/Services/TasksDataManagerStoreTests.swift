//
//  TasksDataManagerStoreTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import CoreData
import SwiftData
import XCTest

@testable import BookPlayerKit

/// A model no schema in `MigrationPlan` knows — what a store written between schema edits
/// (or by a newer build) looks like to this build.
@Model
final class AlienQueueModel {
  var id: String

  init(id: String) {
    self.id = id
  }
}

/// The launch-time store guard. Its previous form matched Cocoa error codes on the thrown
/// error, which SwiftData wraps opaquely, so it never fired and an unknown store crash-looped
/// the app at launch. The decision now comes from the store's own metadata, up front.
final class TasksDataManagerStoreTests: XCTestCase {
  private var storeURL: URL!

  override func setUpWithError() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    storeURL = directory.appendingPathComponent("bp-synctasks.sqlite")
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
  }

  /// Writes an on-disk store for `schema` and releases it.
  private func writeStore(_ schema: Schema) throws {
    let container = try ModelContainer(
      for: schema,
      configurations: ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
    )
    let context = ModelContext(container)
    try context.save()
    XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path))
  }

  // MARK: - Detection

  func testCurrentSchemaStore_isKnownToThePlan() throws {
    try writeStore(Schema(versionedSchema: SchemaV3.self))

    XCTAssertFalse(TasksDataManager.storeIsUnknownToMigrationPlan(at: storeURL))
  }

  /// An older, migratable store must never be set aside — the plan can carry it forward.
  func testOlderSchemaStore_isKnownToThePlan() throws {
    try writeStore(Schema(versionedSchema: SchemaV1.self))

    XCTAssertFalse(TasksDataManager.storeIsUnknownToMigrationPlan(at: storeURL))
  }

  func testAlienSchemaStore_isUnknownToThePlan() throws {
    try writeStore(Schema([AlienQueueModel.self]))

    XCTAssertTrue(TasksDataManager.storeIsUnknownToMigrationPlan(at: storeURL))
  }

  func testMissingStore_isNotUnknown() {
    XCTAssertFalse(TasksDataManager.storeIsUnknownToMigrationPlan(at: storeURL))
  }

  // MARK: - Launch path

  /// The crash the guard existed for and never caught: an unknown store is set aside (kept as
  /// `.incompatible`) and a fresh container opens.
  func testInit_setsAsideAnAlienStoreAndOpensFresh() throws {
    try writeStore(Schema([AlienQueueModel.self]))

    let manager = TasksDataManager(storeURL: storeURL)

    XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path + ".incompatible"), "kept, not deleted")
    XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path), "a fresh store replaces it")
    let context = ModelContext(manager.container)
    XCTAssertEqual(try context.fetchCount(FetchDescriptor<QueuedTaskReferenceModel>()), 0)
  }

  func testInit_keepsACurrentStore() throws {
    try writeStore(Schema(versionedSchema: SchemaV3.self))

    _ = TasksDataManager(storeURL: storeURL)

    XCTAssertFalse(FileManager.default.fileExists(atPath: storeURL.path + ".incompatible"))
  }

  /// Only one set-aside generation survives, so a repeated mismatch cannot pile up copies.
  func testSetAsideStore_replacesThePreviousGeneration() throws {
    try writeStore(Schema([AlienQueueModel.self]))
    TasksDataManager.setAsideStore(at: storeURL)
    XCTAssertFalse(FileManager.default.fileExists(atPath: storeURL.path))

    try writeStore(Schema([AlienQueueModel.self]))
    TasksDataManager.setAsideStore(at: storeURL)

    XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path + ".incompatible"))
    XCTAssertFalse(FileManager.default.fileExists(atPath: storeURL.path))
  }
}
