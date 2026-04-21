//
//  SyncTasksStorageTests.swift
//  BookPlayerTests
//
//  Created by Claude on 2026-04-21.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation
import SwiftData
import XCTest

@testable import BookPlayer
@testable import BookPlayerKit

final class SyncTasksStorageTests: XCTestCase {
  private var tasksDataManager: TasksDataManager!
  private var storage: SyncTasksStorage!

  override func setUpWithError() throws {
    let schema = Schema([
      SyncTasksContainer.self,
      SyncTaskReferenceModel.self,
      UploadTaskModel.self,
      UpdateTaskModel.self,
      MoveTaskModel.self,
      DeleteTaskModel.self,
      DeleteBookmarkTaskModel.self,
      SetBookmarkTaskModel.self,
      RenameFolderTaskModel.self,
      ArtworkUploadTaskModel.self,
      MatchUuidsTaskModel.self
    ])
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    let container = try ModelContainer(for: schema, configurations: config)
    tasksDataManager = TasksDataManager(container: container)
    storage = try SyncTasksStorage(tasksDataManager: tasksDataManager)
  }

  override func tearDown() {
    storage = nil
    tasksDataManager = nil
    super.tearDown()
  }

  /// Progress lookup must key on `uuid`, so a progress dictionary indexed by uuid
  /// surfaces correctly on the returned SyncTaskReference.
  func testGetAllTasks_progressKeyedByUuid_returnsProgressForTask() async throws {
    let uuid = "item-uuid-1"
    let relativePath = "Folder/Book.mp3"
    try await appendUploadTask(uuid: uuid, relativePath: relativePath)

    let references = await storage.getAllTasks(progress: [uuid: 0.42])

    XCTAssertEqual(references.count, 1)
    let reference = try XCTUnwrap(references.first)
    XCTAssertEqual(reference.uuid, uuid)
    XCTAssertEqual(reference.progress, 0.42, accuracy: 0.0001)
  }

  /// Regression guard: with a real uuid, a progress dict keyed by relativePath must NOT resolve.
  func testGetAllTasks_progressKeyedByRelativePath_returnsZero() async throws {
    let uuid = "item-uuid-2"
    let relativePath = "Folder/Other.mp3"
    try await appendUploadTask(uuid: uuid, relativePath: relativePath)

    let references = await storage.getAllTasks(progress: [relativePath: 0.75])

    XCTAssertEqual(references.count, 1)
    let reference = try XCTUnwrap(references.first)
    XCTAssertEqual(reference.progress, 0.0)
  }

  /// Legacy-migrated task references share the same placeholder uuid; the progress key
  /// must fall back to `relativePath` so sibling rows don't collide on the same key.
  func testGetAllTasks_legacyPlaceholderUuid_fallsBackToRelativePath() async throws {
    let relativePath = "Folder/Legacy.mp3"
    try await appendUploadTask(uuid: Constants.legacyUuidPlaceholder, relativePath: relativePath)

    let references = await storage.getAllTasks(progress: [relativePath: 0.6])

    XCTAssertEqual(references.count, 1)
    let reference = try XCTUnwrap(references.first)
    XCTAssertEqual(reference.progress, 0.6, accuracy: 0.0001)
  }

  /// Same fallback applies to the local placeholder used as the schema default.
  func testGetAllTasks_localPlaceholderUuid_fallsBackToRelativePath() async throws {
    let relativePath = "Folder/Local.mp3"
    try await appendUploadTask(uuid: Constants.uuidPlaceholder, relativePath: relativePath)

    let references = await storage.getAllTasks(progress: [relativePath: 0.33])

    XCTAssertEqual(references.count, 1)
    let reference = try XCTUnwrap(references.first)
    XCTAssertEqual(reference.progress, 0.33, accuracy: 0.0001)
  }

  private func appendUploadTask(uuid: String, relativePath: String) async throws {
    let parameters: [String: Any] = [
      "id": UUID().uuidString,
      "uuid": uuid,
      "relativePath": relativePath,
      "originalFileName": "Book.mp3",
      "title": "Book",
      "details": "Author",
      "currentTime": 0.0,
      "duration": 100.0,
      "percentCompleted": 0.0,
      "isFinished": false,
      "orderRank": 0,
      "type": SimpleItemType.book.rawValue,
      "jobType": SyncJobType.upload.rawValue
    ]
    try await storage.appendTask(parameters: parameters)
  }
}
