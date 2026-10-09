//
//  SyncService.swift
//  BookPlayer
//
//  Created by gianni.carlo on 18/4/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import AVFoundation
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
  /// Flag to check if it can sync or not. Owned by `SyncService`; mutate it through
  /// `updateSyncEnabled(_:)` / `logout()` rather than assigning directly.
  var isActive: Bool { get }
  /// Enable or disable syncing in response to account/subscription state. Disabling
  /// also cancels any queued jobs.
  func updateSyncEnabled(_ enabled: Bool)
  /// Tear down sync state on logout/account deletion (stop syncing, clear the queue
  /// and the scheduled-contents flag).
  func logout() async
  /// Completion publisher for ongoing-download tasks
  var downloadCompletedPublisher: PassthroughSubject<(String, String, String?), Never> { get }
  /// Progress publisher for ongoing-download tasks
  var downloadProgressPublisher: PassthroughSubject<(String, String, String?, Double), Never> { get }
  /// Error publisher for ongoing-download tasks
  var downloadErrorPublisher: PassthroughSubject<(String, Error), Never> { get }

  /// Count of the currently queued sync jobs
  func queuedJobsCount() async -> Int
  /// Check if we can safely fetch the list contents
  func canSyncListContents(at relativePath: String?, ignoreLastTimestamp: Bool) async -> Bool

  /// Fetch the contents at the relativePath and override local contents with the remote repsonse
  func syncListContents(at relativePath: String?) async throws

  /// The first sync: registers what the server is missing (the missing-items pass), then
  /// reconciles the library root without deleting anything. Runs after signing in and on
  /// coming back from a lapse
  func syncLibraryContents() async throws

  func syncBookmarksList(relativePath: String) async throws -> [SimpleBookmark]?

  /// Whether the first sync has registered this device's items (after signing in, or on coming
  /// back from a lapse): until then no listing may delete local items
  var hasRunFirstSync: Bool { get }

  /// The missing-items pass outside the first sync: once the account becomes PRO (its books'
  /// files can now go up), and weekly. Runs only when due, sync is on, the first sync has
  /// run and nothing waits in the sync lane; one at a time
  func scheduleMissingItemsIfNeeded() async

  func getRemoteFileURLs(
    of relativePath: String,
    for uuid: String?,
    type: SimpleItemType
  ) async throws -> [RemoteFileURL]

  func downloadRemoteFiles(for item: SimpleLibraryItem) async throws

  func scheduleUpload(items: [SimpleLibraryItem]) async

  func scheduleDelete(_ items: [SimpleLibraryItem], mode: DeleteMode)

  func scheduleMove(items: [LibraryItemRef], to parentFolder: LibraryItemRef?)

  func scheduleRenameFolder(at relativePath: String, name: String, for uuid: String)

  func scheduleSetBookmark(
    relativePath: String,
    time: Double,
    note: String?,
    uuid: String
  )

  func scheduleDeleteBookmark(_ bookmark: SimpleBookmark)

  func scheduleUploadArtwork(relativePath: String, uuid: String)

  /// Upload a newly linked external resource
  func scheduleExternalResourceUpload(_ resource: SyncableExternalResource, relativePath: String, uuid: String)

  /// Delete an external resource on the server
  func scheduleExternalResourceDeletion(providerName: String, providerId: String, relativePath: String, uuid: String)

  /// Get all queued jobs with full parameters for debugging
  func getAllQueuedJobsWithParams() async -> [SyncTask]
  /// Get last sync error information for debugging
  func getLastSyncError() -> SyncErrorInfo?
  /// Cancel all scheduled jobs
  func cancelAllJobs()
  /// Returns once every finished download's follow-up (chapters, verification, media-server
  /// upload scheduling) is done: a background wake awaits it before letting iOS suspend
  func settleDownloads() async
  /// Cancel all scheduled jobs and wait for completion
  func resetAllJobs() async

  /// Cancel ongoing downloads for an item
  func cancelDownload(of item: SimpleLibraryItem) throws

  func getDownloadState(for item: SimpleLibraryItem) -> DownloadState

  /// Check if there's an upload task queued for the item
  func hasUploadTask(for relativePath: String) async -> Bool
  /// Set the last played book (on the background context)
  func setLibraryLastBook(with relativePath: String?) async
}

@Observable
public final class SyncService: SyncServiceProtocol, BPLogger {
  private var libraryService: LibrarySyncProtocol!
  private var accountService: AccountServiceProtocol!
  private var syncQueueService: SyncQueueServiceProtocol!
  var jobManager: JobSchedulerProtocol!
  private var client: NetworkClientProtocol!
  /// Owned here: writes go through `updateSyncEnabled(_:)` / `logout()`, mutated on the
  /// main actor. External callers read only.
  public private(set) var isActive: Bool = false
  /// In-flight logout teardown, awaited before an initial library sync re-schedules,
  /// so a re-login can't begin scheduling until the queue reset has finished.
  /// Lock-guarded rather than @MainActor: the `.logout` sink must assign SYNCHRONOUSLY
  /// (a deferred main-actor hop reopens a window where the re-login gates read nil and
  /// a late resetAllJobs wipes freshly-scheduled jobs), while reads come from arbitrary
  /// async contexts.
  private let teardownTaskLock = NSLock()
  private var _teardownTask: Task<Void, Never>?
  private var teardownTask: Task<Void, Never>? {
    get {
      teardownTaskLock.lock(); defer { teardownTaskLock.unlock() }
      return _teardownTask
    }
    set {
      teardownTaskLock.lock(); defer { teardownTaskLock.unlock() }
      _teardownTask = newValue
    }
  }

  /// Dictionary holding the initiating item relative path as key and the download tasks as value
  private var downloadTasksDictionary = [String: [URLSessionTask]]()
  /// Reference to the initiating item path for the download tasks (relevant for bound books)
  private var ongoingTasksParentReference = [String: String]()
  /// Reference to the parent folder of the initiating item to pass on observer
  private var initiatingFolderReference = [String: String]()
  /// Completion publisher for ongoing-download tasks
  public var downloadCompletedPublisher = PassthroughSubject<(String, String, String?), Never>()
  /// Cancelled publisher for ongoing-download tasks
  public var downloadCancelledPublisher = PassthroughSubject<(String, String, String?), Never>()
  /// Progress publisher for ongoing-download tasks
  public var downloadProgressPublisher = PassthroughSubject<(String, String, String?, Double), Never>()
  /// Error publisher for ongoing-download tasks
  public var downloadErrorPublisher = PassthroughSubject<(String, Error), Never>()
  /// Background URL session to handle downloading synced items
  private var downloadURLSession: BPDownloadURLSession!
  /// Finished downloads still being finalized, so a background wake can wait for them
  private let finalizeLock = NSLock()
  private var finalizeTasks = [UUID: Task<Void, Never>]()
  /// How each AudiobookShelf download in flight finds its file again, by the file's path: a file
  /// replaced since its lookup answers 404 (its id is its inode), and gets one more lookup. A
  /// download can wait a long time to start (Wi-Fi only). In memory: a download restored after a
  /// relaunch just fails, and downloading again looks it up afresh.
  private struct MediaServerDownload {
    let lookup: PlayableChapter.StreamLookup
    let headers: [String: String]
  }
  private let mediaServerDownloadsLock = NSLock()
  private var mediaServerDownloads = [String: MediaServerDownload]()
  /// Tasks whose 404 was retried under a new task, kept so their late delegate callbacks stay
  /// ignored. Only a retry whose lookup finds no file removes its task, to fail the download
  /// through it.
  private var retriedDownloadTasks = Set<Int>()

  private var provider: NetworkProvider<LibraryAPI>!

  /// Only the phone runs the missing-items pass: the watch has downloaded files of its own
  /// and must never upload them
  private var runsMissingItemsPass = false
  /// One pass at a time: an account update and a list refresh can ask together
  private let missingItemsPassLock = NSLock()
  private var isRunningMissingItemsPass = false
  /// Where the first-sync flag and the pass's schedule live (injected by tests)
  private var defaults: UserDefaults = .standard
  /// Bumped (under `missingItemsPassLock`) whenever sync goes off: a pass that began earlier
  /// can't tell a new session from its own by `isActive` alone if sync came back meanwhile
  private var syncSession = 0

  public var hasRunFirstSync: Bool {
    defaults.bool(forKey: Constants.UserDefaults.hasScheduledLibraryContents)
  }

  private var disposeBag = Set<AnyCancellable>()

  public init() {}

  /// Where an external item downloads from — the same resolution PlaybackService uses to
  /// stream it, so the two paths cannot disagree about server, URL or auth headers.
  private var streamResolver: ExternalStreamResolving!
  private var streamLookup: ExternalStreamLooking!

  public func setup(
    isActive: Bool,
    libraryService: LibrarySyncProtocol,
    accountService: AccountServiceProtocol,
    syncQueueService: SyncQueueServiceProtocol,
    client: NetworkClientProtocol = NetworkClient(),
    streamResolver: ExternalStreamResolving = ExternalStreamResolver(),
    streamLookup: ExternalStreamLooking = AudiobookShelfStreamLookup(),
    runsMissingItemsPass: Bool = false,
    userDefaults: UserDefaults = .standard
  ) {
    self.isActive = isActive
    self.runsMissingItemsPass = runsMissingItemsPass
    self.defaults = userDefaults
    self.streamResolver = streamResolver
    self.streamLookup = streamLookup
    self.libraryService = libraryService
    self.accountService = accountService
    // Signed in but not syncing is a lapse too, usually one that happened while the app was
    // closed (the cached entitlement expired), with no transition for updateSyncEnabled to
    // see. A paying subscriber whose cached read is stale lands here as well: harmless, the
    // first sync never clears queued work and only runs once the sync lane is empty
    if runsMissingItemsPass, !isActive, accountService.getAccountId() != nil {
      defaults.set(false, forKey: Constants.UserDefaults.hasScheduledLibraryContents)
    }
    self.syncQueueService = syncQueueService
    self.jobManager = SyncJobScheduler(tasksRepository: syncQueueService.taskContainer)
    // The queue holds the server lanes until told otherwise: a lapsed account's persisted
    // tasks stay put (a fresh install's first RevenueCat fetch may still flip it on) but
    // never hit the server, which would reject them forever
    syncQueueService.setServerLanesEnabled(isActive)
    self.client = client
    self.provider = NetworkProvider(client: client)

    bindObservers()
    setupBackgroundDownloadSession()
  }

  func setupBackgroundDownloadSession() {
    self.downloadURLSession = BPDownloadURLSession { task, progress in
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

    self.downloadURLSession.backgroundSession.getTasksWithCompletionHandler { _, _, downloadTasks in
      for task in downloadTasks {
        guard let relativePath = task.taskDescription else { continue }

        let paths: [String] = relativePath.allRanges(of: "/")
          .map { String(relativePath.prefix(upTo: $0.lowerBound)) }
          .reversed()
        let parentFolder = paths.last

        let initiatingPath = parentFolder ?? relativePath

        var tasksArray = self.downloadTasksDictionary[initiatingPath] ?? []
        tasksArray.append(task)
        self.downloadTasksDictionary[initiatingPath] = tasksArray
        self.ongoingTasksParentReference[relativePath] = initiatingPath
        self.initiatingFolderReference[relativePath] = paths.count > 1 ? parentFolder : nil
      }
    }
  }

  func bindObservers() {
    NotificationCenter.default.publisher(for: .logout, object: nil)
      .sink(receiveValue: { [weak self] _ in
        /// Covers every logout path (iOS sign-out, account deletion, Watch), since
        /// they all post `.logout`. Tears down the queue, the flag, and `isActive`.
        /// Held in `teardownTask` — assigned SYNCHRONOUSLY (lock-guarded) so a
        /// re-login's initial sync can never observe a pre-assignment nil.
        self?.teardownTask = Task { await self?.logout() }
      })
      .store(in: &disposeBag)

    /// Sync ownership lives here, not in the views: any account/subscription change
    /// re-derives whether syncing should be active, and the queue's per-job policy. All
    /// logout paths post `.logout` (handled above), so account-present-but-sync-disabled is
    /// the case we map here.
    NotificationCenter.default.publisher(for: .accountUpdate, object: nil)
      .sink(receiveValue: { [weak self] _ in
        guard let self else { return }
        // The policy first, and right here: `.accountUpdate` is posted on main and the lanes
        // only turn on in a later main-actor step, so no worker can take a held upload under
        // the previous tier's policy (which would drop it as not allowed)
        self.syncQueueService.refreshAccessPolicy()
        guard self.accountService.hasAccount() else { return }
        self.updateSyncEnabled(self.accountService.hasSyncEnabled())
        self.noteProAccess()
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

    /// Same gate as `syncLibraryContents()`: don't reconcile while a logout teardown
    /// is still clearing the queue, in case a fast re-login routed here before the
    /// `hasScheduledLibraryContents` flag was reset.
    await teardownTask?.value

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
    // Its pass queues this device's files for upload: never from the watch
    guard runsMissingItemsPass else {
      throw BookPlayerError.runtimeError("The first sync runs on the phone only")
    }

    /// Wait for any in-flight logout teardown to finish before scheduling, so a fast
    /// logout→login can't have a late `resetAllJobs()` wipe freshly-scheduled jobs.
    await teardownTask?.value

    // Work queued before sync went off is held, never cleared (a paying subscriber can read
    // lapsed at launch): it runs first, so the server has it before it's asked what it's
    // missing. The flag stays off meanwhile, and the next root refresh runs this again
    guard await queuedJobsCount() == 0 else {
      Self.logger.trace("First sync waits for the queued sync tasks")
      return
    }
    guard beginMissingItemsPass() else { return }
    defer { endMissingItemsPass() }
    let session = currentSyncSession()

    Self.logger.trace("Registering what the server is missing")

    // By uuid, never by comparing paths: a path that went stale on this device (after a
    // lapse, the stalest case) would make the server move its item back
    let couldQueueFiles = try await runMissingItemsPass(startsContinuedUploads: true, session: session)
    // Sync went off meanwhile (and maybe came back): its teardown wiped what this queued
    guard isStillSyncSession(session) else { return }
    // Only once its books' files could be queued: an account update may not have given the
    // queue its PRO policy yet, and the next root refresh then runs the pass again
    if couldQueueFiles {
      defaults.set(false, forKey: Constants.UserDefaults.missingItemsPassPending)
    }

    let response = try await fetchContents(at: nil)

    // Checked and written in one step with the session's end, which clears the flag
    guard markFirstSyncDone(in: session) else { return }

    try await processContentsResponse(response, parentFolder: nil, canDelete: false)
  }

  func processContentsResponse(
    _ response: ContentsResponse,
    parentFolder: String?,
    canDelete: Bool
  ) async throws {
    guard !response.content.isEmpty else { return }

    var completeItemsDict = Dictionary(response.content.map { ($0.relativePath, $0) }) { first, _ in first }
    var missingUuidsDict: [String: String] = [:]
    
    response.content.forEach {
      if $0.uuid.isEmpty {
        let newUuid = UUID().uuidString
        completeItemsDict.updateValue($0.copy(uuid: newUuid), forKey: $0.relativePath)
        missingUuidsDict[$0.relativePath] = newUuid
      }
    }

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
      await libraryService.itemExists(for: lastItemPlayed.relativePath)
    {
      try await handleSyncedLastPlayed(item: lastItemPlayed)
    }
    
    await jobManager.scheduleMatchUuidsJob(uuidsDict: missingUuidsDict)
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
    if let remoteLastPlayDateTimestamp = item.lastPlayDateTimestamp {
      let hasNewLastPlayDate = remoteLastPlayDateTimestamp > localLastPlayDateTimestamp
      await libraryService.updateInfo(for: item, ignoreCurrentTime: !hasNewLastPlayDate)
      if hasNewLastPlayDate {
        throw BPSyncError.reloadLastBook(item.relativePath)
      }
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
    let response: BookmarksResponse = try await provider.request(.bookmarks(path: relativePath, uuid: nil))

    return response.bookmarks.map({ SimpleBookmark(from: $0) })
  }

  public func getRemoteFileURLs(
    of relativePath: String,
    for uuid: String?,
    type: SimpleItemType
  ) async throws -> [RemoteFileURL] {
    let response: RemoteFileURLResponseContainer

    switch type {
    case .folder, .bound:
      response = try await provider.request(.remoteContentsURL(path: relativePath, uuid: uuid))
    case .book:
      response = try await self.provider.request(.remoteFileURL(path: relativePath, uuid: uuid))
    }

    guard !response.content.isEmpty else {
      throw BookPlayerError.emptyResponse
    }

    return response.content
  }

  public func downloadRemoteFiles(for item: SimpleLibraryItem) async throws {
    var remoteURLs: [RemoteFileURL] = []
    var isExternalItem = false
    // streamingResource, not first(where:) over an unordered set: it is provider-filtered.
    // The API's markExternalSourceUploaded marks EVERY provider row 'downloaded' for an
    // item, so a dual-linked book's Hardcover row can pass a syncStatus check — and Hardcover
    // has no files. Picking it here threw integration_error_missing_connection on a book
    // whose Jellyfin connection was fine. A streamed volume's books have no link of their own:
    // they download through the volume's.
    if item.type == .book || item.type == .bound, let external = item.externalResources?.streamingResource {
      isExternalItem = true
      remoteURLs = try await mediaServerFileURLs(for: item, resource: external)
    } else {
      remoteURLs = try await getRemoteFileURLs(of: item.relativePath, for: item.uuid, type: item.type)
    }
    
    let processedFolderURL = DataManager.getProcessedFolderURL()
    let folderURLs = remoteURLs.filter({ $0.type != .book })

    /// Handle throwable items first
    if !folderURLs.isEmpty {
      for remoteURL in folderURLs {
        let fileURL = processedFolderURL.appendingPathComponent(remoteURL.relativePath)
        try DataManager.createBackingFolderIfNeeded(fileURL)
      }
    }

    // An external item that produced no URL means its media-server connection isn't
    // resolvable on this device (deleted / never added) — completing silently with zero
    // download tasks strands the user with no spinner and no explanation.
    if isExternalItem, remoteURLs.isEmpty {
      throw BookPlayerError.runtimeError("integration_error_missing_connection".localized)
    }

    let bookURLs = remoteURLs.filter({ $0.type == .book })

    var tasks = [URLSessionTask]()

    for remoteURL in bookURLs {
      let localURL = processedFolderURL.appendingPathComponent(remoteURL.relativePath)
      let downloadUrl = remoteURL.url

      guard !FileManager.default.fileExists(atPath: localURL.path) else {
        mediaServerDownloadsLock.withLock { mediaServerDownloads[remoteURL.relativePath] = nil }
        continue
      }

      if let headers = remoteURL.headers, !headers.isEmpty {
        var request = URLRequest(url: downloadUrl)
        // Forward EVERY header — the dict deliberately includes the connection's custom
        // headers (reverse-proxy gates like Cloudflare Access), not just Authorization.
        for (field, value) in headers {
          request.setValue(value, forHTTPHeaderField: field)
        }
        
        let task = await provider.client.download(
          request: request,
          taskDescription: remoteURL.relativePath,
          session: downloadURLSession.backgroundSession
        )

        tasks.append(task)
      } else {
        let task = await provider.client.download(
          url: downloadUrl,
          taskDescription: remoteURL.relativePath,
          session: downloadURLSession.backgroundSession
        )

        tasks.append(task)
      }
    }

    downloadTasksDictionary[item.relativePath] = tasks
    ongoingTasksParentReference = tasks.reduce(
      into: ongoingTasksParentReference,
      {
        $0[$1.taskDescription!] = item.relativePath
      }
    )
    ongoingTasksParentReference.keys
      .forEach({ initiatingFolderReference[$0] = item.parentFolder })
  }

  /// The files a streamed book or volume downloads from its media server, remembering how to
  /// find each AudiobookShelf file again (`mediaServerDownloads`). Empty when no saved server
  /// matches the link (the caller says so).
  private func mediaServerFileURLs(
    for item: SimpleLibraryItem,
    resource: SimpleExternalResource
  ) async throws -> [RemoteFileURL] {
    // A volume made on another device has no books here until its level is pulled
    if item.type == .bound, isActive, (libraryService.getAllNestedItems(inside: item.relativePath) ?? []).isEmpty {
      try await syncListContents(at: item.relativePath)
    }

    let planner = MediaServerDownloadPlanner(
      streamResolver: streamResolver,
      streamLookup: streamLookup,
      volumeBooks: { [libraryService] path in libraryService?.getAllNestedItems(inside: path) ?? [] }
    )
    let downloads = try await planner.downloads(for: item, resource: resource)
    mediaServerDownloadsLock.withLock {
      for download in downloads {
        if let lookup = download.lookup {
          mediaServerDownloads[download.remoteURL.relativePath] = MediaServerDownload(
            lookup: lookup,
            headers: download.remoteURL.headers ?? [:]
          )
        }
      }
    }

    return downloads.map(\.remoteURL)
  }

  public func scheduleUploadArtwork(relativePath: String, uuid: String) {
    // Artwork goes to S3 like a book's file: PRO only (its route answers LITE with
    // tier_required, as the Android app knows)
    guard isActive, syncQueueService.accessPolicy[.uploadFile] == true else { return }

    Task {
      await jobManager.scheduleArtworkUpload(with: relativePath, for: uuid)
    }
  }

  public func scheduleExternalResourceUpload(
    _ resource: SyncableExternalResource,
    relativePath: String,
    uuid: String
  ) {
    guard isActive else { return }

    Task {
      await jobManager.scheduleExternalResourceUpload(
        for: resource,
        itemOrigin: LibraryItemRef(relativePath: relativePath, uuid: uuid)
      )
    }
  }

  public func scheduleExternalResourceDeletion(
    providerName: String,
    providerId: String,
    relativePath: String,
    uuid: String
  ) {
    guard isActive else { return }

    Task {
      await jobManager.scheduleDeleteExternalResource(
        providerName: providerName,
        providerId: providerId,
        itemOrigin: LibraryItemRef(relativePath: relativePath, uuid: uuid)
      )
    }
  }

  public func getAllQueuedJobsWithParams() async -> [SyncTask] {
    return await jobManager.getAllQueuedJobsWithParams()
  }

  public func getLastSyncError() -> SyncErrorInfo? {
    return syncQueueService.lastSyncError
  }

  public func cancelAllJobs() {
    jobManager.cancelAllJobs()
  }

  public func resetAllJobs() async {
    await jobManager.resetAllJobs()
  }

  /// Enables or disables syncing in response to account/subscription state. Disabling
  /// also cancels any queued jobs. Idempotent — a no-op when the state is unchanged.
  /// `isActive` is mutated on the main actor since it's an `@Observable` value read by
  /// SwiftUI; the actual sync-content refresh is triggered by observers of `isActive`.
  public func updateSyncEnabled(_ enabled: Bool) {
    Task { @MainActor in
      guard self.isActive != enabled else { return }
      self.isActive = enabled
      self.syncQueueService.setServerLanesEnabled(enabled)
      if !enabled {
        // A lapse makes the return a first sync: what's imported meanwhile never reaches the
        // server, and a plain listing would delete it (it isn't on the server)
        self.endSyncSession(resettingFirstSync: self.runsMissingItemsPass)
        self.cancelAllJobs()
        // Clearing the persisted rows isn't enough (develop parity): an operation
        // already executing keeps uploading after the lapse without this. Scoped so
        // in-flight externalUpdate pushes survive — they run on every tier.
        self.syncQueueService.cancelServerQueueOperations()
      }
    }
  }

  /// Tears down sync state when the account logs out (or is deleted): stops syncing,
  /// clears the persisted task queue, and resets the "scheduled library contents" flag
  /// so the next login runs a fresh initial sync from an empty queue. Idempotent.
  public func logout() async {
    // Same main-actor hop as the flag: a fast re-login's updateSyncEnabled(true) runs on
    // main, so a gate write outside this block could land after it and hold the lanes
    await MainActor.run {
      self.isActive = false
      self.syncQueueService.setServerLanesEnabled(false)
    }
    endSyncSession(resettingFirstSync: true)
    for key in [
      Constants.UserDefaults.missingItemsPassLastRun,
      Constants.UserDefaults.missingItemsPassPending,
      Constants.UserDefaults.lastKnownProAccess,
    ] {
      defaults.removeObject(forKey: key)
    }
    await resetAllJobs()
  }
}

extension SyncService {
  public func scheduleMove(items: [LibraryItemRef], to parentFolder: LibraryItemRef?) {
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

    // No orderRank suppression here: automatic sorts are applied at query time
    // and never write ranks, so every rank update that reaches this point is a
    // genuine custom-arrangement change and must sync.
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
  /// - Parameter announcesUploads: whether queued book files may start the continued task
  func handleItemsToUpload(_ items: [SyncableItem], announcesUploads: Bool = true) async {
    for item in items {
      await jobManager.scheduleLibraryItemUploadJob(for: item)
      
      if let externalResources = item.externalResources {
        for externalResource in externalResources {
          await jobManager.scheduleExternalResourceUpload(for: externalResource, itemOrigin: LibraryItemRef(relativePath: item.relativePath, uuid: item.uuid))
        }
      }
    }

    /// Bookmarks after every item, read in batches on a background context: a first sync
    /// registers the whole library, and this runs off main
    let bookmarksByPath = await libraryService.getUserBookmarks(forItemsAt: items.map(\.relativePath))
    for item in items {
      for bookmark in bookmarksByPath[item.relativePath] ?? [] {
        await jobManager.scheduleSetBookmarkJob(
          with: bookmark.relativePath,
          time: floor(bookmark.time),
          note: bookmark.note,
          for: item.uuid
        )
      }
    }

    // Media-server books have no file to upload from here (theirs goes up once downloaded)
    if announcesUploads, items.contains(where: { $0.type == .book && $0.mediaServerProviderName == nil }) {
      await MainActor.run {
        NotificationCenter.default.post(name: .bookUploadsQueued, object: nil)
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
        !contents.isEmpty
      {
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
        await jobManager.scheduleDeleteJob(with: item.relativePath, mode: mode, for: item.uuid)
      }
    }
  }
}

extension SyncService {
  public func scheduleSetBookmark(
    relativePath: String,
    time: Double,
    note: String?,
    uuid: String
  ) {
    guard isActive else { return }

    Task {
      await jobManager.scheduleSetBookmarkJob(
        with: relativePath,
        time: time,
        note: note,
        for: uuid
      )
    }
  }

  public func scheduleDeleteBookmark(_ bookmark: SimpleBookmark) {
    guard isActive else { return }

    Task {
      await jobManager.scheduleDeleteBookmarkJob(
        with: bookmark.relativePath,
        time: bookmark.time,
        for: bookmark.uuid
      )
    }
  }

  public func scheduleRenameFolder(at relativePath: String, name: String, for uuid: String) {
    guard isActive else { return }

    Task {
      await jobManager.scheduleRenameFolderJob(with: relativePath, name: name, for: uuid)
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

    // A media-server file replaced since its lookup: asked for once more under a new task
    enum Retry {
      /// The task's second callback, its 404 already being retried
      case ignore
      case start(MediaServerDownload)
      case none
    }
    let retry: Retry = mediaServerDownloadsLock.withLock {
      if retriedDownloadTasks.contains(task.taskIdentifier) {
        return .ignore
      }
      // `parseErrorFromTask` turns the HTTP status into the code
      guard
        (error as? URLError)?.code.rawValue == 404,
        let download = mediaServerDownloads.removeValue(forKey: relativePath)
      else {
        if error != nil || location != nil {
          mediaServerDownloads[relativePath] = nil
        }
        return .none
      }
      retriedDownloadTasks.insert(task.taskIdentifier)
      return .start(download)
    }
    switch retry {
    case .ignore:
      return
    case .start(let download):
      // Held like a finalize, so a background wake waits for it (`settleDownloads`)
      let id = UUID()
      finalizeLock.withLock {
        finalizeTasks[id] = Task {
          await self.retryMediaServerDownload(download, relativePath: relativePath, failedTask: task)
          _ = self.finalizeLock.withLock { self.finalizeTasks.removeValue(forKey: id) }
        }
      }
      return
    case .none:
      break
    }

    var finalError = error
    var movedFileURL: URL?

    if error == nil,
      let location
    {
      let fileURL = DataManager.getProcessedFolderURL().appendingPathComponent(relativePath)

      do {
        /// If there's already something there, replace with new finished download
        if FileManager.default.fileExists(atPath: fileURL.path) {
          try FileManager.default.removeItem(at: fileURL)
        }
        try DataManager.createContainingFolderIfNeeded(for: fileURL)
        try FileManager.default.moveItem(at: location, to: fileURL)
        movedFileURL = fileURL
      } catch {
        finalError = error
        Self.logger.warning("Error moving downloaded file to the destination: \(error.localizedDescription)")
      }
    }

    /// Capture and clear the per-task bookkeeping synchronously (we're on the
    /// delegate queue). The completion event is emitted later, only after the
    /// file is verified — see `finalizeDownloadedFile`.
    let startingItemPath = ongoingTasksParentReference[relativePath]
    let parentFolderPath = initiatingFolderReference[relativePath]
    // A media-server file being looked up again after its 404 is still to come, though its
    // first task completed
    let retrying = mediaServerDownloadsLock.withLock { retriedDownloadTasks }
    if let startingItemPath,
      downloadTasksDictionary[startingItemPath]?
        .filter({ $0 != task })
        .allSatisfy({ $0.state == .completed && !retrying.contains($0.taskIdentifier) }) == true
    {
      downloadTasksDictionary[startingItemPath] = nil
    }
    ongoingTasksParentReference[relativePath] = nil
    initiatingFolderReference[relativePath] = nil

    /// The download itself failed (network/move error): surface it and stop. We
    /// never emit a completion event for a failed download.
    if let finalError {
      DispatchQueue.main.async {
        self.downloadErrorPublisher.send((relativePath, finalError))
      }
      return
    }

    /// Second delegate callback (`didCompleteWithError` with no location) for a
    /// download that already finished: nothing to move, nothing to announce.
    guard let movedFileURL else { return }

    let id = UUID()
    // Stored under the lock it removes itself with, so an instant finish can't beat the insert
    finalizeLock.withLock {
      finalizeTasks[id] = Task {
        await self.finalizeDownloadedFile(
          relativePath: relativePath,
          fileURL: movedFileURL,
          startingItemPath: startingItemPath,
          parentFolderPath: parentFolderPath
        )
        _ = self.finalizeLock.withLock { self.finalizeTasks.removeValue(forKey: id) }
      }
    }
  }

  /// Looks a media-server file up again after its download's 404 and downloads it once more,
  /// in the failed task's place. Fails the download as usual when the lookup finds no file.
  private func retryMediaServerDownload(
    _ download: MediaServerDownload,
    relativePath: String,
    failedTask: URLSessionTask
  ) async {
    let answer = await streamLookup.files(
      ofItem: download.lookup.itemId,
      on: download.lookup.serverURL,
      headers: download.headers,
      timeout: ExternalStreamLookupTimeout.download
    )
    guard case .answered(let files) = answer, let file = download.lookup.file(in: files) else {
      await failRetriedDownload(
        relativePath: relativePath,
        failedTask: failedTask,
        error: MediaServerDownloadError(lookup: answer) ?? .noFile
      )
      return
    }

    // Cancelled while it was looked up (`cancelDownload`): don't start it again
    guard await onDownloadDelegateQueue({ self.isStillDownloading(failedTask, relativePath: relativePath) }) else { return }

    var request = URLRequest(url: file.url(on: download.lookup.serverURL))
    for (field, value) in download.headers {
      request.setValue(value, forHTTPHeaderField: field)
    }
    let task = await provider.client.download(
      request: request,
      taskDescription: relativePath,
      session: downloadURLSession.backgroundSession
    )
    // No third try: this one's outcome is final. On the delegate queue, where the bookkeeping
    // lives; a download that already finished (or was cancelled) has cleared its entry
    await onDownloadDelegateQueue {
      guard
        self.isStillDownloading(failedTask, relativePath: relativePath),
        let startingItemPath = self.ongoingTasksParentReference[relativePath]
      else {
        task.cancel()
        return
      }
      self.downloadTasksDictionary[startingItemPath] = (self.downloadTasksDictionary[startingItemPath] ?? [])
        .filter { $0 != failedTask } + [task]
    }
  }

  /// Whether the download `failedTask` belonged to is still going: not cancelled, and not
  /// replaced by a new download of the same item (whose entries share its path). On the delegate
  /// queue.
  private func isStillDownloading(_ failedTask: URLSessionTask, relativePath: String) -> Bool {
    guard let startingItemPath = ongoingTasksParentReference[relativePath] else { return false }

    return downloadTasksDictionary[startingItemPath]?.contains(failedTask) == true
  }

  /// The retried download's failure, reported the way any failed download is, unless it was
  /// cancelled meanwhile. On the delegate queue, behind the failed task's own callbacks: it
  /// stops being ignored only once they're done.
  private func failRetriedDownload(relativePath: String, failedTask: URLSessionTask, error: Error) async {
    await onDownloadDelegateQueue {
      self.mediaServerDownloadsLock.withLock { _ = self.retriedDownloadTasks.remove(failedTask.taskIdentifier) }
      guard self.isStillDownloading(failedTask, relativePath: relativePath) else { return }

      self.handleFinishedDownload(task: failedTask, location: nil, error: error)
    }
  }

  /// Runs `work` on the download session's serial delegate queue, where `handleFinishedDownload`
  /// and the download bookkeeping it reads run.
  private func onDownloadDelegateQueue<T>(_ work: @escaping () -> T) async -> T {
    await withCheckedContinuation { continuation in
      downloadURLSession.backgroundSession.delegateQueue.addOperation {
        continuation.resume(returning: work())
      }
    }
  }

  public func settleDownloads() async {
    let tasks = finalizeLock.withLock { Array(finalizeTasks.values) }
    for task in tasks {
      await task.value
    }
  }

  /// Loads chapters, validates the downloaded file, and only then announces
  /// completion. Splitting this out (and gating the completion event on the
  /// validation result) ensures a truncated file is never broadcast as
  /// `.downloaded` before being discarded.
  private func finalizeDownloadedFile(
    relativePath: String,
    fileURL: URL,
    startingItemPath: String?,
    parentFolderPath: String?
  ) async {
    await libraryService.loadChaptersIfNeeded(relativePath: relativePath)

    /// Read on a background context (off the main/view context) — this runs on
    /// the download delegate's queue / a detached task.
    let expectedDuration = await libraryService.getItemDuration(at: relativePath)

    if let verificationError = await verifyDownloadedFile(
      relativePath: relativePath,
      fileURL: fileURL,
      expectedDuration: expectedDuration
    ) {
      DispatchQueue.main.async {
        self.downloadErrorPublisher.send((relativePath, verificationError))
      }
      return
    }

    /// Only announce completion once the file is verified, and only for a tracked
    /// (user-initiated) download — restored/untracked tasks just get validated.
    guard let startingItemPath else { return }
    DispatchQueue.main.async {
      self.downloadCompletedPublisher.send((relativePath, startingItemPath, parentFolderPath))
    }

    // Taken whatever happens next: the lookup was only needed while the file downloaded
    let cameFromMediaServer = mediaServerDownloadsLock.withLock {
      mediaServerDownloads.removeValue(forKey: relativePath) != nil
    }

    guard let snapshot = libraryService.getItemResourcesSnapshot(for: relativePath) else { return }

    // Neither branch is gated on `isActive`, unlike the other `schedule*` paths: the missing-items
    // pass skips a book with its own media-server link, so for one this job is the only way its
    // file reaches the cloud. A download made while sync is off (a lapsed subscriber can still
    // stream) waits in the paused sync lane and uploads once sync is back on.
    guard let externalResource = Self.streamedMediaServerLink(in: snapshot.resources) else {
      // A streamed volume's book has no link of its own: its file goes up like a linked book's,
      // but only when it just came from its server. The volume's link stays `stream` (the server
      // only marks an uploaded book's own links downloaded), so it can't tell a server download
      // from a cloud one; the planned AudiobookShelf lookup can (volumes only come from
      // AudiobookShelf). A cloud download, or any download on the watch, has none
      if cameFromMediaServer,
        let volumePath = LibraryService.parentPath(of: relativePath),
        let volume = libraryService.getItemResourcesSnapshot(for: volumePath),
        volume.resources.contains(where: { ExternalResource.ProviderName(rawValue: $0.providerName)?.isMediaServer == true })
      {
        await jobManager.scheduleResourceToDownload(with: relativePath, for: snapshot.uuid)
      }
      return
    }

    let externalSyncItem = SyncableExternalResource(
      providerName: externalResource.providerName,
      providerId: externalResource.providerId,
      syncStatus: externalResource.syncStatus,
      lastSyncedAt: nil,
      processedFile: true,
      hostId: externalResource.hostId
    )
    await libraryService.updateExternalResource(for: externalSyncItem, itemUuid: snapshot.uuid)
    await jobManager.scheduleResourceToDownload(with: relativePath, for: snapshot.uuid)
  }

  /// The streamed media-server link a finished download marks processed and uploads the file
  /// for. Not just any `stream` row: Android's offload flips every downloaded link back to
  /// `stream`, Hardcover's included, and the links are an unordered set.
  static func streamedMediaServerLink(in resources: [SyncableExternalResource]) -> SyncableExternalResource? {
    resources
      .filter { ExternalResource.ProviderName(rawValue: $0.providerName)?.isMediaServer == true }
      .sorted { ($0.providerName, $0.providerId) < ($1.providerName, $1.providerId) }
      .first { $0.syncStatus == ExternalResource.SyncStatus.stream.rawValue }
  }

  /// Backstop against truncated/botched downloads that finish without surfacing a
  /// network error (e.g. the connection closed early, or watchOS suspended the
  /// background transfer). `URLSession` won't flag these, so a short file would be
  /// promoted as a fully-downloaded book and silently cut playback off partway
  /// through. Returns a non-nil error (and deletes the file) when the download is
  /// rejected; `nil` when the file is acceptable or can't be validated.
  private func verifyDownloadedFile(
    relativePath: String,
    fileURL: URL,
    expectedDuration: Double?
  ) async -> Error? {
    /// No trustworthy reference duration (item not yet stored, or a duration of 0)
    /// means we can't validate — leave the download in place.
    guard let expectedDuration, expectedDuration > 0 else { return nil }

    let actualDuration: Double
    do {
      let asset = AVURLAsset(url: fileURL)
      actualDuration = CMTimeGetSeconds(try await asset.load(.duration))
    } catch {
      /// We have a trustworthy synced duration, so this is a format we can play —
      /// a complete file would be readable. A load failure on a fresh download is
      /// a strong truncation/corruption signal (e.g. a cut-off AAC/m4b missing its
      /// `moov` atom), which is exactly the case a byte/duration check would
      /// otherwise miss. Reject it.
      try? FileManager.default.removeItem(at: fileURL)
      Self.logger.warning(
        "Discarding download for \(relativePath); duration unreadable (likely truncated): \(error.localizedDescription)"
      )
      return DownloadError.durationUnreadable
    }

    guard actualDuration.isFinite else { return nil }

    /// Allow a small tolerance for container/encoder rounding differences.
    let tolerance = max(2, expectedDuration * 0.02)
    guard expectedDuration - actualDuration > tolerance else { return nil }

    try? FileManager.default.removeItem(at: fileURL)
    Self.logger.warning(
      "Discarding truncated download for \(relativePath): expected \(expectedDuration)s, got \(actualDuration)s"
    )
    return DownloadError.durationMismatch(expected: expectedDuration, actual: actualDuration)
  }

  public func cancelDownload(of item: SimpleLibraryItem) throws {
    guard let tasks = downloadTasksDictionary[item.relativePath] else { return }

    var hasCompletedTasks = false

    var events = [(String, String, String?)]()
    for task in tasks {
      guard task.state != .completed else {
        hasCompletedTasks = true
        // A media-server file whose 404 is being retried: clearing its entry stops the retry
        if mediaServerDownloadsLock.withLock({ retriedDownloadTasks.contains(task.taskIdentifier) }),
          let relativePath = task.taskDescription
        {
          let startingItemPath = ongoingTasksParentReference[relativePath]
          ongoingTasksParentReference[relativePath] = nil
          let parentFolderPath = initiatingFolderReference[relativePath]
          initiatingFolderReference[relativePath] = nil

          if let startingItemPath {
            events.append((relativePath, startingItemPath, parentFolderPath))
          }
        }
        continue
      }

      if let relativePath = task.taskDescription {
        let startingItemPath = ongoingTasksParentReference[relativePath]
        ongoingTasksParentReference[relativePath] = nil
        let parentFolderPath = initiatingFolderReference[relativePath]
        initiatingFolderReference[relativePath] = nil

        if let startingItemPath {
          events.append((relativePath, startingItemPath, parentFolderPath))
        }
      }

      task.cancel()
    }

    /// Clean up bound downloads if at least one was finished
    if item.type == .bound,
      hasCompletedTasks
    {
      let fileURL = item.fileURL
      try FileManager.default.removeItem(at: fileURL)
      try FileManager.default.createDirectory(
        at: fileURL,
        withIntermediateDirectories: true,
        attributes: nil
      )
    }

    downloadTasksDictionary[item.relativePath] = nil

    DispatchQueue.main.async {
      for event in events {
        self.downloadCancelledPublisher.send(event)
      }
    }
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

    DispatchQueue.main.async {
      self.downloadProgressPublisher.send(
        (relativePath, initiatingItemRelativePath, parentFolderPath, progress)
      )
    }
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
    /// The link `downloadRemoteFiles` downloads from; a Hardcover link has no file to download
    let streamsFromMediaServer = item.externalResources?.streamingResource != nil
    /// Only process if subscription is active or it streams from a media server
    guard isActive || streamsFromMediaServer else { return .downloaded }
    
    if downloadTasksDictionary[item.relativePath]?.isEmpty == false {
      return .downloading(progress: calculateDownloadProgress(with: item.relativePath))
    }

    let fileURL = item.fileURL

    switch item.type {
    case .book:
      return FileManager.default.fileExists(atPath: fileURL.path) ? .downloaded : .notDownloaded
    case .folder, .bound:
      guard
        let enumerator = FileManager.default.enumerator(
          at: fileURL,
          includingPropertiesForKeys: nil,
          options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        )
      else { return .notDownloaded }

      return libraryService.getMaxItemsCount(at: item.relativePath) == enumerator.allObjects.count
        ? .downloaded : .notDownloaded
    }
  }
}

// MARK: - Missing-items pass

extension SyncService {
  /// How often the pass runs without a tier change
  static let missingItemsPassInterval: TimeInterval = 7 * 24 * 60 * 60

  /// The missing-items pass (bookplayer-api docs/multipart-uploads.md): asks the server about
  /// every uuid in the local library, registers the items it has never seen like an import
  /// and, with S3 access, queues the files of books it holds without one. By uuid, never by
  /// path, so a path that went stale on this device can't move anything back.
  /// - Parameters:
  ///   - startsContinuedUploads: whether queued book files may start the continued task (the
  ///     first sync and a tier change; the weekly run never does)
  ///   - session: the sync session the caller began in (its own, when nil)
  /// - Returns: whether the tier could queue book files (a pending tier change is done)
  @discardableResult
  func runMissingItemsPass(startsContinuedUploads: Bool, session: Int? = nil) async throws -> Bool {
    let session = session ?? currentSyncSession()
    guard let localUuids = await libraryService.fetchAllUuids() else {
      throw BookPlayerError.runtimeError("Couldn't read the library for the missing-items pass")
    }
    let status: ItemsStatusResponse = try await provider.request(.itemsStatus(uuids: localUuids))
    // Sync went off while the server answered (and maybe came back): its teardown already ran
    guard isStillSyncSession(session) else { return false }

    // A book with an upload queued (parked included) isn't lost: leave it to that task
    let queuedUploads = Set(await syncQueueService.taskContainer.getUploadCandidates().map(\.task.uuid))

    let unknownUuids = status.unknown.filter { !queuedUploads.contains($0) }
    var unknownItems = [SyncableItem]()
    if !unknownUuids.isEmpty {
      guard let items = await libraryService.getSyncableItems(forUuids: unknownUuids) else {
        throw BookPlayerError.runtimeError("Couldn't read the items the server is missing")
      }
      unknownItems = try await matchUuids(of: items)
      guard isStillSyncSession(session) else { return false }
      await handleItemsToUpload(unknownItems, announcesUploads: false)
    }

    // A logout during the registrations: don't queue into the next account's session
    guard isStillSyncSession(session) else { return false }
    // Read once: the same answer decides whether files are queued and whether a pending tier
    // change is done
    let canQueueFiles = syncQueueService.accessPolicy[.uploadFile] == true
    var queuedFiles = 0
    if canQueueFiles, !status.unsynced.isEmpty {
      guard let books = await libraryService.getSyncableItems(forUuids: status.unsynced) else {
        throw BookPlayerError.runtimeError("Couldn't read the books the server has no file for")
      }
      queuedFiles = await syncQueueService.scheduleMissingFileUploads(books.compactMap(Self.missingFileUpload(for:)))
    }

    if startsContinuedUploads,
      queuedFiles > 0 || unknownItems.contains(where: { $0.type == .book && $0.mediaServerProviderName == nil })
    {
      await MainActor.run {
        NotificationCenter.default.post(name: .bookUploadsQueued, object: nil)
      }
    }

    // After a logout, the next account starts with no run on record
    guard isStillSyncSession(session) else { return false }
    defaults.set(Date().timeIntervalSince1970, forKey: Constants.UserDefaults.missingItemsPassLastRun)
    return canQueueFiles
  }

  /// Matches the items' uuids by path BEFORE anything registers them: the server may already
  /// hold a row at an item's path under no uuid (a legacy row: the server takes ours) or
  /// another one (the same file imported on another device: this device adopts it, in the
  /// library and every queued task). `PUT /` at such a path would answer with that row without
  /// storing our uuid. Done inline, not as a queued job, so every task registered afterwards
  /// already carries the uuid the server knows. Returns the items as they now are.
  private func matchUuids(of items: [SyncableItem]) async throws -> [SyncableItem] {
    var conflicts = [ItemConflict]()
    let limit = SyncJobScheduler.matchUuidsBatchLimit
    for start in stride(from: 0, to: items.count, by: limit) {
      let batch = items[start..<min(start + limit, items.count)]
      let response: MatchUuidsResponse = try await provider.request(
        .matchUuids(uuidsDictionary: Dictionary(batch.map { ($0.relativePath, $0.uuid) }) { first, _ in first })
      )
      conflicts += response.conflicts
    }
    guard !conflicts.isEmpty else { return items }

    try await syncQueueService.applyUuidConflicts(conflicts)
    let adopted = Dictionary(conflicts.map { ($0.key, $0.uuid) }) { first, _ in first }
    guard let current = await libraryService.getSyncableItems(forUuids: items.map { adopted[$0.uuid] ?? $0.uuid }) else {
      throw BookPlayerError.runtimeError("Couldn't read the items after matching their uuids")
    }
    return current
  }

  /// A book the server holds without its file, worth uploading from here: not streamed from a
  /// media server (its file goes up once downloaded, through the pipe job), its file on this
  /// device, and within the 10 GiB ceiling (a too-large book the user dismissed stays gone)
  static func missingFileUpload(for item: SyncableItem) -> MissingFileUpload? {
    guard item.type == .book, item.mediaServerProviderName == nil else { return nil }
    let fileURL = DataManager.getProcessedFolderURL().appendingPathComponent(item.relativePath)
    guard
      let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
      values.isRegularFile == true,
      let size = values.fileSize,
      Int64(size) <= FileUploadOperation.maxFileSize
    else { return nil }
    return MissingFileUpload(uuid: item.uuid, relativePath: item.relativePath, fileURL: fileURL)
  }

  public func scheduleMissingItemsIfNeeded() async {
    guard runsMissingItemsPass, isActive else { return }
    // Until then, the first sync is the pass
    guard defaults.bool(forKey: Constants.UserDefaults.hasScheduledLibraryContents) else { return }
    guard isMissingItemsPassDue() else { return }

    guard beginMissingItemsPass() else { return }
    defer { endMissingItemsPass() }

    await teardownTask?.value
    let session = currentSyncSession()
    // A tier change that arrived during a weekly run runs right after it, not a week later
    while isMissingItemsPassDue() {
      // Off (a logout or lapse) the pass stops without recording a run: stop with it. Queued
      // changes haven't reached the server yet: a queued import would come back unknown and be
      // registered twice
      guard isStillSyncSession(session), hasRunFirstSync, await jobManager.queuedJobsCount() == 0 else { return }
      let isPending = defaults.bool(forKey: Constants.UserDefaults.missingItemsPassPending)
      do {
        let couldQueueFiles = try await runMissingItemsPass(startsContinuedUploads: isPending, session: session)
        guard isPending else { continue }
        guard couldQueueFiles else { return }
        defaults.set(false, forKey: Constants.UserDefaults.missingItemsPassPending)
      } catch {
        Self.logger.error("Missing-items pass failed: \(error.localizedDescription)")
        return
      }
    }
  }

  private func isMissingItemsPassDue() -> Bool {
    let lastRun = defaults.double(forKey: Constants.UserDefaults.missingItemsPassLastRun)
    return defaults.bool(forKey: Constants.UserDefaults.missingItemsPassPending)
      || Date().timeIntervalSince1970 - lastRun >= Self.missingItemsPassInterval
  }

  /// LITE → PRO: the books registered without their file can now upload, so the next pass is
  /// due at once (and starts the continued task). Leaving PRO drops a pass still pending. The
  /// first reading (an app update, a fresh install, a sign-in) is no tier change: the first
  /// sync and the weekly run cover what's missing
  func noteProAccess() {
    guard runsMissingItemsPass else { return }
    let isPro = accountService.getAccessLevel() == .pro
    if let wasPro = defaults.object(forKey: Constants.UserDefaults.lastKnownProAccess) as? Bool, wasPro != isPro {
      defaults.set(isPro, forKey: Constants.UserDefaults.missingItemsPassPending)
    }
    defaults.set(isPro, forKey: Constants.UserDefaults.lastKnownProAccess)
    Task { await self.scheduleMissingItemsIfNeeded() }
  }

  private func beginMissingItemsPass() -> Bool {
    missingItemsPassLock.withLock {
      guard !isRunningMissingItemsPass else { return false }
      isRunningMissingItemsPass = true
      return true
    }
  }

  private func endMissingItemsPass() {
    missingItemsPassLock.withLock { isRunningMissingItemsPass = false }
  }

  private func currentSyncSession() -> Int {
    missingItemsPassLock.withLock { syncSession }
  }

  private func isStillSyncSession(_ session: Int) -> Bool {
    isActive && missingItemsPassLock.withLock { syncSession == session }
  }

  /// Sync went off (a logout, a lapse): the session ends and, where asked, the first-sync
  /// flag clears in the same step, so a pass from the old session can't mark itself done after
  private func endSyncSession(resettingFirstSync: Bool) {
    missingItemsPassLock.withLock {
      syncSession += 1
      if resettingFirstSync {
        defaults.set(false, forKey: Constants.UserDefaults.hasScheduledLibraryContents)
      }
    }
  }

  private func markFirstSyncDone(in session: Int) -> Bool {
    missingItemsPassLock.withLock {
      guard isActive, syncSession == session else { return false }
      defaults.set(true, forKey: Constants.UserDefaults.hasScheduledLibraryContents)
      return true
    }
  }
}
