//
// AppDelegate.swift
// BookPlayer
//
// Created by Gianni Carlo on 7/1/16.
// Copyright © 2016 BookPlayer LLC. All rights reserved.
//

import AVFoundation
import AppIntents
import BackgroundTasks
import BookPlayerKit
import Combine
import CoreData
import Intents
import MediaPlayer
import RevenueCat
import Sentry
import StoreKit
import UIKit
import WatchConnectivity

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, BPLogger {
  static weak var shared: AppDelegate?
  var pendingURLActions = [Action]()

  var window: UIWindow?

  let databaseInitializer = DatabaseInitializer()
  var coreServices: CoreServices?

  /// Internal property used as a fallback in ``activeSceneDelegate``
  var lastSceneToResignActive: SceneDelegate?
  /// Access the current (or last) active scene delegate to present VCs or alerts
  var activeSceneDelegate: SceneDelegate? {
    if let scene = UIApplication.shared.connectedScenes.first(
      where: { $0.activationState == .foregroundActive }
    ) as? UIWindowScene,
      let delegate = scene.delegate as? SceneDelegate
    {
      return delegate
    } else {
      return lastSceneToResignActive
    }
  }
  /// Reference for observers
  private var crashReportsAccessObserver: NSKeyValueObservation?
  /// Background refresh task identifier
  private lazy var refreshTaskIdentifier =
    "\(Bundle.main.configurationString(for: .bundleIdentifier)).background.refresh"
  /// Database backup task identifier
  private lazy var databaseBackupTaskIdentifier =
    "\(Bundle.main.configurationString(for: .bundleIdentifier)).background.database.backup"

  /// Reference to the task that creates the core services
  var setupCoreServicesTask: Task<(), Error>?
  var errorCoreServicesSetup: Error?

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    Self.shared = self

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.messageReceived),
      name: .messageReceived,
      object: nil
    )

    // register background refresh tasks
    self.setupBackgroundRefreshTasks()
    // register for remote events
    self.setupMPRemoteCommands()
    // Setup RevenueCat
    self.setupRevenueCat()
    // Setup Sentry
    self.setupSentry()
    // Setup core services
    self.setupCoreServices()

    return true
  }

  func application(
    _ application: UIApplication,
    handle intent: INIntent,
    completionHandler: @escaping (INIntentResponse) -> Void
  ) {
    let response: INPlayMediaIntentResponse
    do {
      try ActionParserService.process(intent)
      response = INPlayMediaIntentResponse(code: .success, userActivity: nil)
    } catch {
      response = INPlayMediaIntentResponse(code: .failure, userActivity: nil)
    }
    completionHandler(response)
  }

  @objc func messageReceived(_ notification: Notification) {
    guard
      let message = notification.userInfo as? [String: Any],
      let action = CommandParser.parse(message)
    else {
      return
    }

    DispatchQueue.main.async {
      ActionParserService.handleAction(action)
    }
  }

  override func accessibilityPerformMagicTap() -> Bool {
    guard
      let playerManager = self.coreServices?.playerManager,
      playerManager.currentItem != nil
    else {
      UIAccessibility.post(
        notification: .announcement,
        argument: "voiceover_no_title".localized
      )
      return false
    }

    playerManager.playPause()
    return true
  }

  func setupMPRemoteCommands() {
    Task {
      self.setupMPPlaybackRemoteCommands()
      self.setupMPSkipRemoteCommands()
    }
  }

  func setupMPPlaybackRemoteCommands() {
    let center = MPRemoteCommandCenter.shared()
    // Play / Pause
    center.togglePlayPauseCommand.isEnabled = true
    center.togglePlayPauseCommand.addTarget { [weak self] (_) -> MPRemoteCommandHandlerStatus in
      guard let playerManager = self?.coreServices?.playerManager else {
        return .commandFailed
      }

      let wasPlaying = playerManager.isPlaying
      playerManager.playPause()

      if wasPlaying,
        UIApplication.shared.applicationState == .background
      {
        self?.scheduleAppRefresh()
      }
      return .success
    }

    center.playCommand.isEnabled = true
    center.playCommand.addTarget { [weak self] (_) -> MPRemoteCommandHandlerStatus in
      guard let playerManager = self?.coreServices?.playerManager else {
        return .commandFailed
      }

      let wasPlaying = playerManager.isPlaying
      playerManager.playPause()

      if wasPlaying,
        UIApplication.shared.applicationState == .background
      {
        self?.scheduleAppRefresh()
      }
      return .success
    }

    center.pauseCommand.isEnabled = true
    center.pauseCommand.addTarget { [weak self] (_) -> MPRemoteCommandHandlerStatus in
      guard let playerManager = self?.coreServices?.playerManager else {
        return .commandFailed
      }

      playerManager.pause()

      if UIApplication.shared.applicationState == .background {
        self?.scheduleAppRefresh()
      }

      return .success
    }

    setupChangePlaybackPositionCommand()
  }

  func setupChangePlaybackPositionCommand() {
    let center = MPRemoteCommandCenter.shared()
    center.changePlaybackPositionCommand.isEnabled = UserDefaults.standard.bool(
      forKey: Constants.UserDefaults.seekProgressBarEnabled
    )
    center.changePlaybackPositionCommand.addTarget { [weak self] remoteEvent in
      guard
        let playerManager = self?.coreServices?.playerManager,
        let currentItem = playerManager.currentItem,
        let event = remoteEvent as? MPChangePlaybackPositionCommandEvent
      else { return .commandFailed }

      var newTime = event.positionTime

      if UserDefaults.sharedDefaults.bool(forKey: Constants.UserDefaults.chapterContextEnabled),
        let currentChapter = currentItem.currentChapter
      {
        newTime += currentChapter.start
      }

      playerManager.jumpTo(newTime, recordBookmark: true)

      return .success
    }
  }

  // For now, seek forward/backward and next/previous track perform the same function
  func setupMPSkipRemoteCommands() {
    let center = MPRemoteCommandCenter.shared()
    // Forward
    center.skipForwardCommand.preferredIntervals = [NSNumber(value: PlayerManager.forwardInterval)]
    center.skipForwardCommand.addTarget { [weak self] (_) -> MPRemoteCommandHandlerStatus in
      guard let playerManager = self?.coreServices?.playerManager else { return .commandFailed }

      playerManager.forward()
      return .success
    }

    center.nextTrackCommand.addTarget { [weak self] (_) -> MPRemoteCommandHandlerStatus in
      guard let playerManager = self?.coreServices?.playerManager else { return .commandFailed }

      playerManager.forward()
      return .success
    }

    center.seekForwardCommand.addTarget { [weak self] (commandEvent) -> MPRemoteCommandHandlerStatus in
      guard let cmd = commandEvent as? MPSeekCommandEvent,
        cmd.type == .endSeeking
      else {
        return .success
      }

      guard let playerManager = self?.coreServices?.playerManager else { return .success }

      // End seeking
      playerManager.forward()
      return .success
    }

    // Rewind
    center.skipBackwardCommand.preferredIntervals = [NSNumber(value: PlayerManager.rewindInterval)]
    center.skipBackwardCommand.addTarget { [weak self] (_) -> MPRemoteCommandHandlerStatus in
      guard let playerManager = self?.coreServices?.playerManager else { return .commandFailed }

      playerManager.rewind()
      return .success
    }

    center.previousTrackCommand.addTarget { [weak self] (_) -> MPRemoteCommandHandlerStatus in
      guard let playerManager = self?.coreServices?.playerManager else { return .commandFailed }

      playerManager.rewind()
      return .success
    }

    center.seekBackwardCommand.addTarget { [weak self] (commandEvent) -> MPRemoteCommandHandlerStatus in
      guard
        let cmd = commandEvent as? MPSeekCommandEvent,
        cmd.type == .endSeeking
      else {
        return .success
      }

      guard let playerManager = self?.coreServices?.playerManager else { return .success }

      // End seeking
      playerManager.rewind()
      return .success
    }
  }

  func setupRevenueCat() {
    let revenueCatApiKey: String = Bundle.main.configurationValue(
      for: .revenueCat
    )
    Purchases.logLevel = .error
    Purchases.configure(withAPIKey: revenueCatApiKey)
  }

  /// Setup observer for user preference, and setup Sentry based on initial value
  func setupSentry() {
    let userDefaults = UserDefaults.standard
    crashReportsAccessObserver = userDefaults.observe(
      \.userSettingsCrashReportsDisabled
    ) { [weak self] object, _ in
      self?.handleSentryPreference(
        isDisabled: object.userSettingsCrashReportsDisabled
      )
    }

    handleSentryPreference(
      isDisabled: userDefaults.bool(
        forKey: Constants.UserDefaults.crashReportsDisabled
      )
    )
  }

  /// Setup or stop Sentry based on flag
  /// - Parameter isDisabled: Determines user preference for crash reports
  private func handleSentryPreference(isDisabled: Bool) {
    guard !isDisabled else {
      SentrySDK.close()
      return
    }

    let sentryDSN: String = Bundle.main.configurationValue(for: .sentryDSN)
    // Create a Sentry client
    SentrySDK.start { options in
      options.dsn = "https://\(sentryDSN)"
      options.debug = false
      options.enableCoreDataTracing = false
      options.enableFileIOTracing = false
      options.enableAppHangTracking = false
      options.tracesSampleRate = 0.5
    }
  }

  func requestReview() {
    if let scene = UIApplication.shared.connectedScenes.first(where: {
      $0.activationState == .foregroundActive
    }) as? UIWindowScene {
      AppStore.requestReview(in: scene)
    }
  }

  func playLastBook() {
    guard
      let playerManager = coreServices?.playerManager,
      playerManager.hasLoadedBook()
    else {
      UserDefaults.standard.set(true, forKey: Constants.UserActivityPlayback)
      return
    }

    playerManager.play()
  }

  func showPlayer() {
    guard
      let playerManager = coreServices?.playerManager,
      playerManager.hasLoadedBook()
    else {
      UserDefaults.standard.set(true, forKey: Constants.UserDefaults.showPlayer)
      return
    }

    if let mainCoordinator = activeSceneDelegate?.mainCoordinator,
      !mainCoordinator.hasPlayerShown()
    {
      mainCoordinator.showPlayer()
    }
  }
}

// MARK: - Background tasks

extension AppDelegate {

  func setupBackgroundRefreshTasks() {
    NotificationCenter.default.addObserver(
      forName: UIApplication.didEnterBackgroundNotification,
      object: nil,
      queue: nil
    ) { _ in
      if self.coreServices?.playerManager.isPlaying != true {
        self.scheduleAppRefresh()
      }
    }

    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: refreshTaskIdentifier,
      using: nil
    ) { task in
      guard let refreshTask = task as? BGAppRefreshTask else { return }

      self.handleAppRefresh(task: refreshTask)
    }

    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: databaseBackupTaskIdentifier,
      using: nil
    ) { task in
      guard let backupTask = task as? BGAppRefreshTask else { return }

      self.handleDatabaseBackup(task: backupTask)
    }

    // Schedule the first database backup
    scheduleDatabaseBackup()
  }

  func scheduleAppRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: refreshTaskIdentifier)
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)

    try? BGTaskScheduler.shared.submit(request)
  }

  func handleAppRefresh(task: BGAppRefreshTask) {
    guard let syncService = coreServices?.syncService else { return }

    let refreshOperation = RefreshTaskOperation(syncService: syncService)

    refreshOperation.completionBlock = { [weak self] in
      let success = !refreshOperation.isCancelled

      if !success {
        self?.scheduleAppRefresh()
      }

      task.setTaskCompleted(success: success)
    }

    task.expirationHandler = {
      refreshOperation.cancel()
      refreshOperation.finish()
    }

    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 1

    queue.addOperation(refreshOperation)
  }

  // MARK: - Database Backup

  func scheduleDatabaseBackup() {
    let request = BGAppRefreshTaskRequest(identifier: databaseBackupTaskIdentifier)

    // Schedule for midnight
    let calendar = Calendar.current
    let now = Date()
    var components = calendar.dateComponents([.year, .month, .day], from: now)

    // Set time to midnight
    components.hour = 0
    components.minute = 0
    components.second = 0

    // Get next midnight if it's already past midnight today
    if let midnight = calendar.date(from: components) {
      let nextMidnight =
        midnight > now
        ? midnight
        : calendar.date(byAdding: .day, value: 1, to: midnight)
          ?? Date(timeIntervalSinceNow: 24 * 60 * 60)
      request.earliestBeginDate = nextMidnight
    } else {
      // Fallback: schedule for 24 hours from now
      request.earliestBeginDate = Date(timeIntervalSinceNow: 24 * 60 * 60)
    }

    do {
      try BGTaskScheduler.shared.submit(request)
      Self.logger.info("Database backup scheduled for: \(request.earliestBeginDate?.description ?? "unknown")")
    } catch {
      Self.logger.error("Failed to schedule database backup: \(error.localizedDescription)")
    }
  }

  func handleDatabaseBackup(task: BGAppRefreshTask) {
    let backupOperation = BackupDatabaseOperation()

    backupOperation.completionBlock = { [weak self] in
      // Always reschedule for next day
      self?.scheduleDatabaseBackup()

      // Always mark as completed to prevent iOS throttling
      task.setTaskCompleted(success: true)
    }

    task.expirationHandler = {
      backupOperation.cancel()
      backupOperation.finish()
    }

    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 1

    queue.addOperation(backupOperation)
  }
}

// - MARK: Core services

extension AppDelegate {
  func setupCoreServices() {
    setupCoreServicesTask = Task {
      do {
        let stack = try await databaseInitializer.loadCoreDataStack()
        let coreServices = createCoreServicesIfNeeded(from: stack)

        AppDependencyManager.shared.add(dependency: coreServices.playerLoaderService)
        AppDependencyManager.shared.add(dependency: coreServices.libraryService)
      } catch {
        errorCoreServicesSetup = error
      }
    }
  }

  func resetCoreServices() {
    setupCoreServicesTask?.cancel()
    setupCoreServicesTask = nil
    errorCoreServicesSetup = nil
    setupCoreServices()
  }

  func createCoreServicesIfNeeded(from stack: CoreDataStack) -> CoreServices {
    if let coreServices = self.coreServices {
      return coreServices
    } else {
      let dataManager = DataManager(coreDataStack: stack)
      let accountService = makeAccountService(dataManager: dataManager)
      let bookMetadataService = makeBookMetadataService()
      let libraryService = makeLibraryService(dataManager: dataManager, bookMetadataService: bookMetadataService)
      let syncService = makeSyncService(accountService: accountService, libraryService: libraryService)
      let playbackService = makePlaybackService(libraryService: libraryService)
      let playerManager = PlayerManager(
        libraryService: libraryService,
        playbackService: playbackService,
        syncService: syncService,
        speedService: SpeedService(libraryService: libraryService),
        shakeMotionService: ShakeMotionService(),
        widgetReloadService: WidgetReloadService()
      )
      let watchService = PhoneWatchConnectivityService(
        libraryService: libraryService,
        playbackService: playbackService,
        playerManager: playerManager
      )
      let playerLoaderService = makePlayerLoaderService(
        syncService: syncService,
        libraryService: libraryService,
        playbackService: playbackService,
        playerManager: playerManager
      )
      let hardcoverService = makeHardcoverService(libraryService: libraryService)

      let coreServices = CoreServices(
        accountService: accountService,
        dataManager: dataManager,
        hardcoverService: hardcoverService,
        libraryService: libraryService,
        playbackService: playbackService,
        playerLoaderService: playerLoaderService,
        playerManager: playerManager,
        syncService: syncService,
        watchService: watchService
      )

      self.coreServices = coreServices

      return coreServices
    }
  }

  private func makeAccountService(dataManager: DataManager) -> AccountService {
    let service = AccountService()
    service.setup(dataManager: dataManager)
    return service
  }

  private func makeBookMetadataService() -> BookMetadataService {
    return BookMetadataService()
  }

  private func makeLibraryService(dataManager: DataManager, bookMetadataService: BookMetadataServiceProtocol) -> LibraryService {
    let service = LibraryService()
    service.setup(dataManager: dataManager, bookMetadataService: bookMetadataService)
    return service
  }

  private func makeSyncService(accountService: AccountService, libraryService: LibraryService) -> SyncService {
    let service = SyncService()
    service.setup(isActive: accountService.hasSyncEnabled(), libraryService: libraryService)
    return service
  }

  private func makePlaybackService(libraryService: LibraryService) -> PlaybackService {
    let service = PlaybackService()
    service.setup(libraryService: libraryService)
    return service
  }

  private func makePlayerLoaderService(
    syncService: SyncService,
    libraryService: LibraryService,
    playbackService: PlaybackService,
    playerManager: PlayerManager
  ) -> PlayerLoaderService {
    let service = PlayerLoaderService()
    service.setup(
      syncService: syncService,
      libraryService: libraryService,
      playbackService: playbackService,
      playerManager: playerManager
    )
    return service
  }

  private func makeHardcoverService(libraryService: LibraryService) -> HardcoverService {
    let service = HardcoverService()
    service.setup(libraryService: libraryService)
    return service
  }
}
