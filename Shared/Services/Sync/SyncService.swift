//
//  SyncService.swift
//  BookPlayer
//
//  Created by gianni.carlo on 18/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Combine
import Foundation
import RevenueCat

/// Sync errors that must be handled (not shown as alerts)
public enum BPSyncError: Error {
  /// The library did not have a last book, and needs to reload the player
  /// - Parameter String: relative path of the remote last played book
  case reloadLastBook(String)
  /// The stored last book is different than the remote one, the caller should handle the override conditions
  /// - Parameter String: relative path of the remote last played book
  case differentLastBook(String)
}

/// sourcery: AutoMockable
public protocol SyncServiceProtocol {
  /// Flag to check if it can sync or not
  var isActive: Bool { get set }
  /// Count of the currently queued sync jobs
  var queuedJobsCount: Int { get }

  /// Fetch the contents at the relativePath and override local contents with the remote repsonse
  func syncListContents(at relativePath: String?) async throws -> SyncableItem?

  /// Fetch the synced identifiers and upload new local items
  /// Note: Should only be called once when the user logs in
  func syncLibraryContents() async throws -> SyncableItem?

  func syncBookmarksList(relativePath: String) async throws -> [SimpleBookmark]?

  func getRemoteFileURLs(
    of relativePath: String,
    type: SimpleItemType
  ) async throws -> [RemoteFileURL]

  func downloadRemoteFiles(
    for relativePath: String,
    type: SimpleItemType,
    delegate: URLSessionTaskDelegate
  ) async throws -> [URLSessionDownloadTask]

  func scheduleUpload(items: [SimpleLibraryItem])

  func scheduleDelete(_ items: [SimpleLibraryItem], mode: DeleteMode)

  func scheduleMove(items: [String], to parentFolder: String?)

  func scheduleRenameFolder(at relativePath: String, name: String)

  func scheduleSetBookmark(
    relativePath: String,
    time: Double,
    note: String?
  )

  func scheduleDeleteBookmark(_ bookmark: SimpleBookmark)

  func scheduleUploadArtwork(relativePath: String)

  /// Get all queued jobs
  func getAllQueuedJobs() -> [QueuedJobInfo]
  /// Cancel all scheduled jobs
  func cancelAllJobs()
}

public final class SyncService: SyncServiceProtocol, BPLogger {
  let libraryService: LibrarySyncProtocol
  var jobManager: JobSchedulerProtocol
  let client: NetworkClientProtocol
  public var isActive: Bool

  public var queuedJobsCount: Int { jobManager.queuedJobsCount }

  private let provider: NetworkProvider<LibraryAPI>

  private var disposeBag = Set<AnyCancellable>()

  public init(
    isActive: Bool,
    libraryService: LibrarySyncProtocol,
    jobManager: JobSchedulerProtocol = SyncJobScheduler(),
    client: NetworkClientProtocol = NetworkClient()
  ) {
    self.isActive = isActive
    self.libraryService = libraryService
    self.jobManager = jobManager
    self.client = client
    self.provider = NetworkProvider(client: client)

    bindObservers()
  }

  func bindObservers() {
    NotificationCenter.default.publisher(for: .logout, object: nil)
      .sink(receiveValue: { [weak self] _ in
        self?.isActive = false
        UserDefaults.standard.set(
          false,
          forKey: Constants.UserDefaults.hasScheduledLibraryContents
        )
      })
      .store(in: &disposeBag)

    libraryService.metadataUpdatePublisher.sink { [weak self] params in
      self?.scheduleMetadataUpdate(params: params)
    }
    .store(in: &disposeBag)

    libraryService.progressUpdatePublisher.sink { [weak self] params in
      self?.scheduleMetadataUpdate(params: params)
    }
    .store(in: &disposeBag)
  }

  public func syncListContents(
    at relativePath: String?
  ) async throws -> SyncableItem? {
    guard isActive else {
      throw BookPlayerError.networkError("Sync is not enabled")
    }

    guard UserDefaults.standard.bool(forKey: Constants.UserDefaults.hasQueuedJobs) == false else {
      throw BookPlayerError.runtimeError("Can't fetch items while there are sync operations in progress")
    }

    let userDefaultsKey = "\(Constants.UserDefaults.lastSyncTimestamp)_\(relativePath ?? "library")"
    let now = Date().timeIntervalSince1970
    let lastSync = UserDefaults.standard.double(forKey: userDefaultsKey)

    /// Do not sync if one minute hasn't passed since last sync
    guard now - lastSync > 60 else {
      throw BookPlayerError.networkError("Throttled sync operation")
    }

    UserDefaults.standard.set(
      Date().timeIntervalSince1970,
      forKey: userDefaultsKey
    )

    Self.logger.trace("Fetching list of contents")

    let response = try await fetchContents(at: relativePath)

    try await processContentsResponse(response, parentFolder: relativePath, canDelete: true)

    return response.lastItemPlayed
  }

  public func syncLibraryContents() async throws -> SyncableItem? {
    guard
      isActive,
      UserDefaults.standard.bool(forKey: Constants.UserDefaults.hasQueuedJobs) == false
    else {
      throw BookPlayerError.networkError("Sync is not enabled")
    }

    Self.logger.trace("Fetching synced library identifiers")

    let fetchedIdentifiers = try await fetchSyncedIdentifiers()

    if let itemsToUpload = await libraryService.getItemsToSync(remoteIdentifiers: fetchedIdentifiers),
       !itemsToUpload.isEmpty {
      Self.logger.trace("Scheduling upload tasks")
      handleItemsToUpload(itemsToUpload)
    }

    let response = try await fetchContents(at: nil)

    try await processContentsResponse(response, parentFolder: nil, canDelete: false)

    return response.lastItemPlayed
  }

  func processContentsResponse(
    _ response: ContentsResponse,
    parentFolder: String?,
    canDelete: Bool
  ) async throws {
    guard !response.content.isEmpty else { return }

    let itemsDict = Dictionary(response.content.map { ($0.relativePath, $0) }) { first, _ in first }

    await libraryService.updateInfo(for: itemsDict, parentFolder: parentFolder)

    await libraryService.storeNewItems(from: itemsDict, parentFolder: parentFolder)

    if canDelete {
      await libraryService.removeItems(notIn: Array(itemsDict.keys), parentFolder: parentFolder)
    }

    /// Only handle if the last item played is stored in the local library
    /// Note: we cannot just store the item, because we lack the info of the possible parent folders
    if let lastItemPlayed = response.lastItemPlayed,
       await libraryService.itemExists(for: lastItemPlayed.relativePath) {
      try await handleSyncedLastPlayed(item: lastItemPlayed)
    }
  }

  func handleSyncedLastPlayed(item: SyncableItem) async throws {
    guard
      let localLastItem = libraryService.getLibraryLastItem(),
      let localLastPlayDateTimestamp = localLastItem.lastPlayDate?.timeIntervalSince1970
    else {
      await libraryService.updateInfo(for: item)
      await libraryService.setLibraryLastBook(with: item.relativePath)
      throw BPSyncError.reloadLastBook(item.relativePath)
    }

    guard item.relativePath == localLastItem.relativePath else {
      await libraryService.updateInfo(for: item)
      throw BPSyncError.differentLastBook(item.relativePath)
    }

    /// Only update the time if the remote last played timestamp is greater than the local timestamp
    guard
      let remoteLastPlayDateTimestamp = item.lastPlayDateTimestamp,
      remoteLastPlayDateTimestamp > localLastPlayDateTimestamp
    else {
      return
    }

    await libraryService.updateInfo(for: item)
  }

  public func syncBookmarksList(relativePath: String) async throws -> [SimpleBookmark]? {
    guard
      isActive,
      UserDefaults.standard.bool(forKey: Constants.UserDefaults.hasQueuedJobs) == false
    else {
      throw BookPlayerError.networkError("Sync is not enabled")
    }

    let bookmarks = try await fetchBookmarks(for: relativePath)

    for bookmark in bookmarks {
      await libraryService.addBookmark(from: bookmark)
    }

    return libraryService.getBookmarks(of: .user, relativePath: relativePath)
  }

  func fetchSyncedIdentifiers() async throws -> [String] {
    let response: IdentifiersResponse = try await self.provider.request(.syncedIdentifiers)

    return response.content
  }

  func fetchContents(at relativePath: String?) async throws -> ContentsResponse {
    let path: String
    if let relativePath = relativePath {
      path = "\(relativePath)/"
    } else {
      path = ""
    }

    let response: ContentsResponse = try await self.provider.request(.contents(path: path))

    return response
  }

  func fetchBookmarks(for relativePath: String) async throws -> [SimpleBookmark] {
    let response: BookmarksResponse = try await provider.request(.bookmarks(path: relativePath))

    return response.bookmarks.map({ SimpleBookmark(from: $0) })
  }

  public func getRemoteFileURLs(
    of relativePath: String,
    type: SimpleItemType
  ) async throws -> [RemoteFileURL] {
    let response: RemoteFileURLResponseContainer

    switch type {
    case .folder, .bound:
      response = try await provider.request(.remoteContentsURL(path: relativePath))
    case .book:
      response = try await self.provider.request(.remoteFileURL(path: relativePath))
    }

    guard !response.content.isEmpty else {
      throw BookPlayerError.emptyResponse
    }

    return response.content
  }

  public func downloadRemoteFiles(
    for relativePath: String,
    type: SimpleItemType,
    delegate: URLSessionTaskDelegate
  ) async throws -> [URLSessionDownloadTask] {
    let remoteURLs = try await getRemoteFileURLs(of: relativePath, type: type)

    let folderURLs = remoteURLs.filter({ $0.type != .book })

    /// Handle throwable items first
    if !folderURLs.isEmpty {
      let processedFolderURL = DataManager.getProcessedFolderURL()

      for remoteURL in folderURLs {
        let fileURL = processedFolderURL.appendingPathComponent(remoteURL.relativePath)
        try DataManager.createBackingFolderIfNeeded(fileURL)
      }
    }

    let bookURLs = remoteURLs.filter({ $0.type == .book })

    var tasks = [URLSessionDownloadTask]()

    for remoteURL in bookURLs {
      let task = self.provider.client.download(
        url: remoteURL.url,
        taskDescription: remoteURL.relativePath,
        delegate: delegate
      )

      tasks.append(task)
    }

    return tasks
  }

  public func scheduleUploadArtwork(relativePath: String) {
    guard isActive else { return }

    jobManager.scheduleArtworkUpload(with: relativePath)
  }

  public func getAllQueuedJobs() -> [QueuedJobInfo] {
    return jobManager.getAllQueuedJobs()
  }

  public func cancelAllJobs() {
    jobManager.cancelAllJobs()
  }
}

extension SyncService {
  public func scheduleMove(items: [String], to parentFolder: String?) {
    guard isActive else { return }

    for relativePath in items {
      jobManager.scheduleMoveItemJob(with: relativePath, to: parentFolder)
    }
  }
}

extension SyncService {
  func scheduleMetadataUpdate(params: [String: Any]) {
    guard
      isActive,
      let relativePath = params["relativePath"] as? String
    else { return }

    var params = params

    /// Override param `lastPlayDate` if it exists with the proper name
    if let lastPlayDate = params.removeValue(forKey: #keyPath(LibraryItem.lastPlayDate)) {
      params["lastPlayDateTimestamp"] = lastPlayDate
    }

    jobManager.scheduleMetadataUpdateJob(with: relativePath, parameters: params)
  }
}

extension SyncService {
  func handleItemsToUpload(_ items: [SyncableItem]) {
    for item in items {
      jobManager.scheduleLibraryItemUploadJob(for: item)
    }

    /// Handle bookmarks in separate loop, as the viewContext can be unreliable
    for item in items {
      if let bookmarks = libraryService.getBookmarks(of: .user, relativePath: item.relativePath) {
        for bookmark in bookmarks {
          jobManager.scheduleSetBookmarkJob(
            with: bookmark.relativePath,
            time: floor(bookmark.time),
            note: bookmark.note
          )
        }
      }
    }
  }

  /// Schedule upload tasks for recently imported books and folders
  public func scheduleUpload(items: [SimpleLibraryItem]) {
    guard isActive else { return }

    let syncItems = items.map({ SyncableItem(from: $0) })

    let folders = items.filter({ $0.type != .book })

    var itemsToUpload = syncItems

    for folder in folders {
      if let contents = self.libraryService.getAllNestedItems(inside: folder.relativePath),
         !contents.isEmpty {
        itemsToUpload.append(contentsOf: contents)
      }
    }

    handleItemsToUpload(itemsToUpload)
  }
}

// MARK: - Delete functionality
extension SyncService {
  public func scheduleDelete(_ items: [SimpleLibraryItem], mode: DeleteMode) {
    guard isActive else { return }

    for item in items {
      jobManager.scheduleDeleteJob(with: item.relativePath, mode: mode)
    }
  }
}

extension SyncService {
  public func scheduleSetBookmark(
    relativePath: String,
    time: Double,
    note: String?
  ) {
    guard isActive else { return }

    jobManager.scheduleSetBookmarkJob(
      with: relativePath,
      time: time,
      note: note
    )
  }

  public func scheduleDeleteBookmark(_ bookmark: SimpleBookmark) {
    guard isActive else { return }

    jobManager.scheduleDeleteBookmarkJob(
      with: bookmark.relativePath,
      time: bookmark.time
    )
  }

  public func scheduleRenameFolder(at relativePath: String, name: String) {
    guard isActive else { return }

    jobManager.scheduleRenameFolderJob(with: relativePath, name: name)
  }
}
