//
//  SyncService.swift
//  BookPlayer
//
//  Created by gianni.carlo on 18/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Combine
import Foundation

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
  /// Completion publisher for ongoing-download tasks
  var downloadCompletedPublisher: PassthroughSubject<(String, String, String?), Never> { get }
  /// Progress publisher for ongoing-download tasks
  var downloadProgressPublisher: PassthroughSubject<(String, String, String?, Double), Never> { get }
  /// Error publisher for ongoing-download tasks
  var downloadErrorPublisher: PassthroughSubject<(String, Error), Never> { get }

  /// Count of the currently queued sync jobs
  func queuedJobsCount() async -> Int
  /// Observe the queued jobs count
  func observeTasksCount() -> AnyPublisher<Int, Never>
  /// Check if we can safely fetch the list contents
  func canSyncListContents(at relativePath: String?, ignoreLastTimestamp: Bool) async -> Bool

  /// Fetch the contents at the relativePath and override local contents with the remote repsonse
  func syncListContents(at relativePath: String?) async throws

  /// Fetch the synced identifiers and upload new local items
  /// Note: Should only be called once when the user logs in
  func syncLibraryContents() async throws

  func syncBookmarksList(relativePath: String) async throws -> [SimpleBookmark]?

  /// Fetch the remote synced identifiers
  func fetchSyncedIdentifiers() async throws -> [String]

  func getRemoteFileURLs(
    of relativePath: String,
    type: SimpleItemType
  ) async throws -> [RemoteFileURL]

  func downloadRemoteFiles(for item: SimpleLibraryItem) async throws

  func scheduleUpload(items: [SimpleLibraryItem]) async

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
  func getAllQueuedJobs() async -> [SyncTaskReference]
  /// Cancel all scheduled jobs
  func cancelAllJobs()

  /// Cancel ongoing downloads for an item
  func cancelDownload(of item: SimpleLibraryItem) throws

  func getDownloadState(for item: SimpleLibraryItem) -> DownloadState

  /// Check if there's an upload task queued for the item
  func hasUploadTask(for relativePath: String) async -> Bool
  /// Set the last played book (on the background context)
  func setLibraryLastBook(with relativePath: String?) async
}

public final class SyncService: SyncServiceProtocol, BPLogger {
  let libraryService: LibrarySyncProtocol
  private let tasksCountService: SyncTasksCountServiceProtocol
  var jobManager: JobSchedulerProtocol
  let client: NetworkClientProtocol
  public var isActive: Bool

  /// Dictionary holding the initiating item relative path as key and the download tasks as value
  private lazy var downloadTasksDictionary = [String: [URLSessionTask]]()
  /// Reference to the initiating item path for the download tasks (relevant for bound books)
  private lazy var ongoingTasksParentReference = [String: String]()
  /// Reference to the parent folder of the initiating item to pass on observer
  private lazy var initiatingFolderReference = [String: String]()
  /// Completion publisher for ongoing-download tasks
  public var downloadCompletedPublisher = PassthroughSubject<(String, String, String?), Never>()
  /// Progress publisher for ongoing-download tasks
  public var downloadProgressPublisher = PassthroughSubject<(String, String, String?, Double), Never>()
  /// Error publisher for ongoing-download tasks
  public var downloadErrorPublisher = PassthroughSubject<(String, Error), Never>()
  /// Background URL session to handle downloading synced items
  private lazy var downloadURLSession: BPDownloadURLSession = {
    BPDownloadURLSession { task, progress in
      self.handleDownloadProgressUpdated(
        task: task,
        individualProgress: progress
      )
    } didFinishDownloadingTask: { task, location, error in
      self.handleFinishedDownload(
        task: task,
        location: location,
        error: error
      )
    }
  }()

  private let provider: NetworkProvider<LibraryAPI>

  private var disposeBag = Set<AnyCancellable>()

  public init(
    isActive: Bool,
    libraryService: LibrarySyncProtocol,
    tasksCountService: SyncTasksCountServiceProtocol = SyncTasksCountService(),
    jobManager: JobSchedulerProtocol = SyncJobScheduler(),
    client: NetworkClientProtocol = NetworkClient()
  ) {
    self.isActive = isActive
    self.libraryService = libraryService
    self.tasksCountService = tasksCountService
    self.jobManager = jobManager
    self.client = client
    self.provider = NetworkProvider(client: client)

    bindObservers()
  }

  func bindObservers() {
    NotificationCenter.default.publisher(for: .logout, object: nil)
      .sink(receiveValue: { _ in
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

  /// Count of the currently queued sync jobs
  public func queuedJobsCount() async -> Int {
    return await jobManager.queuedJobsCount()
  }

  public func observeTasksCount() -> AnyPublisher<Int, Never> {
    return tasksCountService.observeTasksCount()
  }

  public func canSyncListContents(at relativePath: String?, ignoreLastTimestamp: Bool) async -> Bool {
    guard isActive else {
      Self.logger.trace("Sync is not enabled")
      return false
    }

    guard await jobManager.queuedJobsCount() == 0 else {
      Self.logger.trace("Can't fetch items while there are sync operations in progress")
      return false
    }

    let userDefaultsKey = "\(Constants.UserDefaults.lastSyncTimestamp)_\(relativePath ?? "library")"
    let now = Date().timeIntervalSince1970
    let lastSync = UserDefaults.standard.double(forKey: userDefaultsKey)

    /// Do not sync if one minute hasn't passed since last sync
    guard ignoreLastTimestamp || now - lastSync > 60 else {
      Self.logger.trace("Throttled sync operation")
      return false
    }

    return true
  }

  public func syncListContents(
    at relativePath: String?
  ) async throws {
    Self.logger.trace("Fetching list of contents")

    let response = try await fetchContents(at: relativePath)

    try await processContentsResponse(response, parentFolder: relativePath, canDelete: true)

    UserDefaults.standard.set(
      Date().timeIntervalSince1970,
      forKey: "\(Constants.UserDefaults.lastSyncTimestamp)_\(relativePath ?? "library")"
    )
  }

  public func syncLibraryContents() async throws {
    guard isActive else {
      throw BookPlayerError.networkError("Sync is not enabled")
    }

    guard await queuedJobsCount() == 0 else {
      Self.logger.trace("Can't sync library while there are sync operations in progress")
      return
    }

    Self.logger.trace("Fetching synced library identifiers")

    let fetchedIdentifiers = try await fetchSyncedIdentifiers()

    if let itemsToUpload = await libraryService.getItemsToSync(remoteIdentifiers: fetchedIdentifiers),
       !itemsToUpload.isEmpty {
      Self.logger.trace("Scheduling upload tasks")
      await handleItemsToUpload(itemsToUpload)
    }

    let response = try await fetchContents(at: nil)

    UserDefaults.standard.set(
      true,
      forKey: Constants.UserDefaults.hasScheduledLibraryContents
    )

    try await processContentsResponse(response, parentFolder: nil, canDelete: false)
  }

  func processContentsResponse(
    _ response: ContentsResponse,
    parentFolder: String?,
    canDelete: Bool
  ) async throws {
    guard !response.content.isEmpty else { return }

    let completeItemsDict = Dictionary(response.content.map { ($0.relativePath, $0) }) { first, _ in first }

    var filteredItemsDict = completeItemsDict
    /// Avoid updating the last played info preemptively
    if let lastItemPlayed = response.lastItemPlayed {
      filteredItemsDict.removeValue(forKey: lastItemPlayed.relativePath)
    }
    await libraryService.updateInfo(for: filteredItemsDict, parentFolder: parentFolder)

    await libraryService.storeNewItems(from: completeItemsDict, parentFolder: parentFolder)

    if canDelete {
      await libraryService.removeItems(notIn: Array(completeItemsDict.keys), parentFolder: parentFolder)
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
      let localLastItem = await libraryService.fetchLibraryLastItem(),
      let localLastPlayDateTimestamp = localLastItem.lastPlayDate?.timeIntervalSince1970
    else {
      await libraryService.updateInfo(for: item)
      await libraryService.updateLibraryLastBook(with: item.relativePath)
      throw BPSyncError.reloadLastBook(item.relativePath)
    }

    guard item.relativePath == localLastItem.relativePath else {
      await libraryService.updateInfo(for: item)
      throw BPSyncError.differentLastBook(item.relativePath)
    }

    /// Only update the time if the remote last played timestamp is greater than the local timestamp
    if let remoteLastPlayDateTimestamp = item.lastPlayDateTimestamp,
       remoteLastPlayDateTimestamp > localLastPlayDateTimestamp {
      await libraryService.updateInfo(for: item)
      throw BPSyncError.reloadLastBook(item.relativePath)
    }
  }

  public func setLibraryLastBook(with relativePath: String?) async {
    await libraryService.updateLibraryLastBook(with: relativePath)
  }

  public func syncBookmarksList(relativePath: String) async throws -> [SimpleBookmark]? {
    guard isActive else {
      throw BookPlayerError.networkError("Sync is not enabled")
    }

    guard await queuedJobsCount() == 0 else {
      throw BookPlayerError.networkError("Can't sync bookmarks while there are sync operations in progress")
    }

    let bookmarks = try await fetchBookmarks(for: relativePath)

    for bookmark in bookmarks {
      await libraryService.addBookmark(from: bookmark)
    }

    return libraryService.getBookmarks(of: .user, relativePath: relativePath)
  }

  public func fetchSyncedIdentifiers() async throws -> [String] {
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

  public func downloadRemoteFiles(for item: SimpleLibraryItem) async throws {
    let remoteURLs = try await getRemoteFileURLs(of: item.relativePath, type: item.type)

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

    var tasks = [URLSessionTask]()

    for remoteURL in bookURLs {
      let task = await provider.client.download(
        url: remoteURL.url,
        taskDescription: remoteURL.relativePath,
        session: downloadURLSession.backgroundSession
      )

      tasks.append(task)
    }

    downloadTasksDictionary[item.relativePath] = tasks
    ongoingTasksParentReference = tasks.reduce(
      into: ongoingTasksParentReference, {
        $0[$1.taskDescription!] = item.relativePath
      }
    )
    ongoingTasksParentReference.keys
      .forEach({ initiatingFolderReference[$0] = item.parentFolder })
  }

  public func scheduleUploadArtwork(relativePath: String) {
    guard isActive else { return }

    Task {
      await jobManager.scheduleArtworkUpload(with: relativePath)
    }
  }

  public func getAllQueuedJobs() async -> [SyncTaskReference] {
    return await jobManager.getAllQueuedJobs()
  }

  public func cancelAllJobs() {
    jobManager.cancelAllJobs()
  }
}

extension SyncService {
  public func scheduleMove(items: [String], to parentFolder: String?) {
    guard isActive else { return }

    Task {
      for relativePath in items {
        await jobManager.scheduleMoveItemJob(with: relativePath, to: parentFolder)
      }
    }
  }
}

extension SyncService {
  func scheduleMetadataUpdate(params: [String: Any]) {
    guard
      isActive,
      let relativePath = params["relativePath"] as? String
    else { return }

    Task {
      var params = params

      /// Override param `lastPlayDate` if it exists with the proper name
      if let lastPlayDate = params.removeValue(forKey: #keyPath(LibraryItem.lastPlayDate)) {
        params["lastPlayDateTimestamp"] = lastPlayDate
      }

      await jobManager.scheduleMetadataUpdateJob(with: relativePath, parameters: params)
    }
  }
}

extension SyncService {
  func handleItemsToUpload(_ items: [SyncableItem]) async {
    for item in items {
      await jobManager.scheduleLibraryItemUploadJob(for: item)
    }

    /// Handle bookmarks in separate loop, as the viewContext can be unreliable
    for item in items {
      if let bookmarks = libraryService.getBookmarks(of: .user, relativePath: item.relativePath) {
        for bookmark in bookmarks {
          await jobManager.scheduleSetBookmarkJob(
            with: bookmark.relativePath,
            time: floor(bookmark.time),
            note: bookmark.note
          )
        }
      }
    }
  }

  /// Schedule upload tasks for recently imported books and folders
  public func scheduleUpload(items: [SimpleLibraryItem]) async {
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

    await handleItemsToUpload(itemsToUpload)
  }

  /// Check if there's an upload task queued for the item
  public func hasUploadTask(for relativePath: String) async -> Bool {
    return await jobManager.hasUploadTask(for: relativePath)
  }
}

// MARK: - Delete functionality
extension SyncService {
  public func scheduleDelete(_ items: [SimpleLibraryItem], mode: DeleteMode) {
    guard isActive else { return }

    Task {
      for item in items {
        await jobManager.scheduleDeleteJob(with: item.relativePath, mode: mode)
      }
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

    Task {
      await jobManager.scheduleSetBookmarkJob(
        with: relativePath,
        time: time,
        note: note
      )
    }
  }

  public func scheduleDeleteBookmark(_ bookmark: SimpleBookmark) {
    guard isActive else { return }

    Task {
      await jobManager.scheduleDeleteBookmarkJob(
        with: bookmark.relativePath,
        time: bookmark.time
      )
    }
  }

  public func scheduleRenameFolder(at relativePath: String, name: String) {
    guard isActive else { return }

    Task {
      await jobManager.scheduleRenameFolderJob(with: relativePath, name: name)
    }
  }
}

extension SyncService {
  private func handleFinishedDownload(
    task: URLSessionTask,
    location: URL?,
    error: Error?
  ) {
    guard let relativePath = task.taskDescription else { return }

    do {
      if error == nil,
         let location {
        let fileURL = DataManager.getProcessedFolderURL().appendingPathComponent(relativePath)

        /// If there's already something there, replace with new finished download
        if FileManager.default.fileExists(atPath: fileURL.path) {
          try FileManager.default.removeItem(at: fileURL)
        }
        try DataManager.createContainingFolderIfNeeded(for: fileURL)
        try FileManager.default.moveItem(at: location, to: fileURL)

        Task {
          await self.libraryService.loadChaptersIfNeeded(relativePath: relativePath)
        }
      }
    } catch {
      Self.logger.trace("Error moving downloaded file to the destination: \(error.localizedDescription)")
    }

    if let error {
      DispatchQueue.main.async {
        self.downloadErrorPublisher.send((relativePath, error))
      }
    }

    guard let startingItemPath = ongoingTasksParentReference[relativePath] else {
      initiatingFolderReference[relativePath] = nil
      return
    }

    let parentFolderPath = initiatingFolderReference[relativePath]

    /// cleanup individual reference
    if downloadTasksDictionary[startingItemPath]?
      .filter({ $0 != task })
      .allSatisfy({ $0.state == .completed }) == true {
      downloadTasksDictionary[startingItemPath] = nil
    }
    ongoingTasksParentReference[relativePath] = nil
    initiatingFolderReference[relativePath] = nil

    DispatchQueue.main.async {
      self.downloadCompletedPublisher.send((relativePath, startingItemPath, parentFolderPath))
    }
  }

  public func cancelDownload(of item: SimpleLibraryItem) throws {
    guard let tasks = downloadTasksDictionary[item.relativePath] else { return }

    var hasCompletedTasks = false

    for task in tasks {
      guard task.state != .completed else {
        hasCompletedTasks = true
        continue
      }

      if let relativePath = task.taskDescription {
        ongoingTasksParentReference[relativePath] = nil
        initiatingFolderReference[relativePath] = nil
      }

      task.cancel()
    }

    /// Clean up bound downloads if at least one was finished
    if item.type == .bound,
       hasCompletedTasks {
      let fileURL = item.fileURL
      try FileManager.default.removeItem(at: fileURL)
      try FileManager.default.createDirectory(
        at: fileURL,
        withIntermediateDirectories: true,
        attributes: nil
      )
    }

    downloadTasksDictionary[item.relativePath] = nil
  }

  /// Handler called when the download has finished for a task
  func handleDownloadProgressUpdated(task: URLSessionTask, individualProgress: Double) {
    guard
      let relativePath = task.taskDescription,
      let initiatingItemRelativePath = ongoingTasksParentReference[relativePath]
    else { return }

    let progress: Double
    /// For individual items, the `fractionCompleted` of the current task can be 0
    let calculatedProgress = calculateDownloadProgress(with: initiatingItemRelativePath)
    if calculatedProgress != 0 && calculatedProgress.isFinite {
      progress = calculatedProgress
    } else {
      progress = individualProgress
    }

    let parentFolderPath = initiatingFolderReference[relativePath]
    downloadProgressPublisher.send(
      (relativePath, initiatingItemRelativePath, parentFolderPath, progress)
    )
  }

  /// Calculate the overall download progress for an item (useful for bound books)
  func calculateDownloadProgress(with relativePath: String) -> Double {
    guard let tasks = downloadTasksDictionary[relativePath] else { return 1.0 }

    let completedTasksCount = tasks.filter({ $0.state == .completed }).count
    let runningTasksProgress = tasks.filter({ $0.state == .running })
      .reduce(0.0, { $0 + $1.progress.fractionCompleted })

    return (runningTasksProgress + Double(completedTasksCount)) / Double(tasks.count)
  }

  /// Get download state of an item
  public func getDownloadState(for item: SimpleLibraryItem) -> DownloadState {
    /// Only process if subscription is active
    guard isActive else { return .downloaded }

    if downloadTasksDictionary[item.relativePath]?.isEmpty == false {
      return .downloading(progress: calculateDownloadProgress(with: item.relativePath))
    }

    let fileURL = item.fileURL

    if (item.type == .bound || item.type == .folder),
       let enumerator = FileManager.default.enumerator(
        at: fileURL,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
       ),
       enumerator.nextObject() == nil {
      return .notDownloaded
    }

    if FileManager.default.fileExists(atPath: fileURL.path) {
      return .downloaded
    }

    return .notDownloaded
  }
}
