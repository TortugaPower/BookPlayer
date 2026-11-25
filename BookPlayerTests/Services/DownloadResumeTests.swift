//
//  DownloadResumeTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Combine
import Foundation
import SwiftData
import XCTest

@testable import BookPlayer
@testable import BookPlayerKit

/// A cloud download the system cancels (a force-quit, background updates turned off, too few
/// resources) carries on from where it stopped under a new task, with no error shown. Every other
/// failure, the user's own cancel included, fails as before.
final class DownloadResumeTests: XCTestCase {
  private let folderPath = "Book Folder"
  private let bookPath = "Book Folder/book.opus"
  private let resumeData = Data("resume here".utf8)
  private var tasksDataManager: TasksDataManager!
  private var client: NetworkClientMock!
  private var sync: SyncService!
  private var errors = [String]()
  private var disposeBag = Set<AnyCancellable>()

  override func setUpWithError() throws {
    let schema = Schema(versionedSchema: SchemaV3.self)
    let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    tasksDataManager = TasksDataManager(container: try ModelContainer(for: schema, configurations: config))
    let queue = SyncQueueService(maxConcurrentTasks: 1)
    queue.taskContainer = SyncQueueRepository(tasksDataManager: tasksDataManager)
    queue.tasksDataManager = tasksDataManager

    let libraryService = LibraryService()
    libraryService.setup(
      dataManager: DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null")),
      audioMetadataService: AudioMetadataService()
    )

    client = NetworkClientMock(mockedResponse: Empty())
    sync = SyncService()
    sync.setup(
      isActive: true,
      libraryService: libraryService,
      accountService: AccountServiceMock(account: nil),
      syncQueueService: queue,
      client: client
    )
    sync.downloadErrorPublisher
      .sink { [weak self] relativePath, _ in self?.errors.append(relativePath) }
      .store(in: &disposeBag)
  }

  override func tearDown() {
    disposeBag.removeAll()
    sync = nil
    client = nil
    tasksDataManager = nil
    super.tearDown()
  }

  // MARK: - Which stops carry on

  func testOnlyADownloadTheSystemCancelledCarriesOn() {
    XCTAssertEqual(SyncService.resumeData(afterFailure: forceQuit()), resumeData)
    XCTAssertEqual(
      SyncService.resumeData(afterFailure: URLError(.cancelled, userInfo: [
        NSURLSessionDownloadTaskResumeData: resumeData,
        NSURLErrorBackgroundTaskCancelledReasonKey: NSURLErrorCancelledReasonBackgroundUpdatesDisabled,
      ])),
      resumeData
    )

    XCTAssertNil(SyncService.resumeData(afterFailure: usersCancel()), "the user's cancel stays cancelled")
    XCTAssertNil(
      SyncService.resumeData(afterFailure: URLError(.cannotWriteToFile, userInfo: [NSURLSessionDownloadTaskResumeData: resumeData])),
      "a write the full disk refused would fail again on every resume"
    )
    XCTAssertNil(
      SyncService.resumeData(afterFailure: URLError(.timedOut, userInfo: [NSURLSessionDownloadTaskResumeData: resumeData]))
    )
    XCTAssertNil(
      SyncService.resumeData(afterFailure: URLError(.cancelled, userInfo: [
        NSURLErrorBackgroundTaskCancelledReasonKey: NSURLErrorCancelledReasonInsufficientSystemResources,
      ])),
      "a partial file the system deleted can't carry on"
    )
    // `BPTaskDownloadDelegate` turns an error answer (an expired link) into its status code
    XCTAssertNil(SyncService.resumeData(afterFailure: URLError(URLError.Code(rawValue: 403))))
    XCTAssertNil(SyncService.resumeData(afterFailure: nil))
  }

  // MARK: - Carrying on

  func testADownloadStoppedByAForceQuitCarriesOnFromWhereItStopped() {
    // At the next launch the session lists the stopped download, then delivers its outcome
    let stopped = download(trackedAsRestored: true)

    sync.handleFinishedDownload(task: stopped, location: nil, error: forceQuit())
    drainMainQueue()

    XCTAssertEqual(client.resumedDownloads.map(\.resumeData), [resumeData])
    XCTAssertEqual(client.resumedDownloads.map(\.taskDescription), [bookPath])
    XCTAssertEqual(errors, [], "no error: the row keeps downloading")
    XCTAssertTrue(isDownloading(folderPath))
  }

  func testAStoppedDownloadNobodyTrackedIsTrackedOnceItCarriesOn() {
    let stopped = download(trackedAsRestored: false)

    sync.handleFinishedDownload(task: stopped, location: nil, error: forceQuit())
    drainMainQueue()

    XCTAssertEqual(client.resumedDownloads.count, 1)
    XCTAssertEqual(errors, [])
    XCTAssertTrue(isDownloading(folderPath))
  }

  func testTheUsersCancelDoesNotCarryOn() {
    let cancelled = download(trackedAsRestored: true)

    sync.handleFinishedDownload(task: cancelled, location: nil, error: usersCancel())
    drainMainQueue()

    XCTAssertTrue(client.resumedDownloads.isEmpty)
    XCTAssertEqual(errors, [bookPath])
  }

  // MARK: - Helpers

  private func forceQuit() -> URLError {
    URLError(.cancelled, userInfo: [
      NSURLSessionDownloadTaskResumeData: resumeData,
      NSURLErrorBackgroundTaskCancelledReasonKey: NSURLErrorCancelledReasonUserForceQuitApplication,
    ])
  }

  /// `cancel()` gives no reason
  private func usersCancel() -> URLError {
    URLError(.cancelled, userInfo: [NSURLSessionDownloadTaskResumeData: resumeData])
  }

  private func download(trackedAsRestored: Bool) -> URLSessionTask {
    let task = URLSession.shared.downloadTask(with: URL(string: "https://example.com/book.opus")!)
    task.taskDescription = bookPath
    if trackedAsRestored {
      sync.trackDownloadFromAnEarlierLaunch(task)
    }
    return task
  }

  private func isDownloading(_ relativePath: String) -> Bool {
    let folder = SimpleLibraryItem(
      title: relativePath,
      details: "",
      speed: 1,
      currentTime: 0,
      duration: 0,
      percentCompleted: 0,
      isFinished: false,
      relativePath: relativePath,
      remoteURL: nil,
      artworkURL: nil,
      orderRank: 0,
      parentFolder: nil,
      originalFileName: relativePath,
      lastPlayDate: nil,
      type: .folder,
      uuid: UUID().uuidString,
      externalResources: nil
    )
    if case .downloading = sync.getDownloadState(for: folder) {
      return true
    }
    return false
  }

  /// Errors reach the publisher through the main queue
  private func drainMainQueue() {
    let drained = expectation(description: "main queue drained")
    DispatchQueue.main.async { drained.fulfill() }
    wait(for: [drained], timeout: 1)
  }
}
