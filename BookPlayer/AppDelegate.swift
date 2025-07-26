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
import DirectoryWatcher
import Intents
import MediaPlayer
import RealmSwift
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
  var documentFolderWatcher: DirectoryWatcher?
  var sharedFolderWatcher: DirectoryWatcher?

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
    // register document's folder listener
    self.setupDocumentListener()
    // Setup RevenueCat
    self.setupRevenueCat()
    // Setup Sentry
    self.setupSentry()
    // Setup Realm
    self.setupRealm()
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

  func createCoreServicesIfNeeded(from stack: CoreDataStack) -> CoreServices {
    if let coreServices = self.coreServices {
      return coreServices
    } else {
      let dataManager = DataManager(coreDataStack: stack)
      let accountService = AccountService()
      accountService.setup(dataManager: dataManager)
      let libraryService = LibraryService()
      libraryService.setup(dataManager: dataManager)
      let syncService = SyncService()
      syncService.setup(
        isActive: accountService.hasSyncEnabled(),
        libraryService: libraryService
      )
      let playbackService = PlaybackService(libraryService: libraryService)
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
      let playerLoaderService = PlayerLoaderService(
        syncService: syncService,
        libraryService: libraryService,
        playbackService: playbackService,
        playerManager: playerManager
      )

      let hardcoverService = HardcoverService()
      hardcoverService.setup(libraryService: libraryService)

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
    center.changePlaybackPositionCommand.isEnabled  = !UserDefaults.standard.bool(forKey: Constants.UserDefaults.seekProgressBarDisabled)
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

  /// Initialize Realm empty database
  func setupRealm() {
    /// Tasks database
    let tasksRealmURL = DataManager.getSyncTasksRealmURL()
    if !FileManager.default.fileExists(atPath: tasksRealmURL.path) {
      _ = try! Realm(configuration: Realm.Configuration(fileURL: tasksRealmURL))
    }
  }

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
    databaseInitializer.cleanupStoreFiles()
    setupCoreServices()
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

  func setupDocumentListener() {
    let newFilesCallback: (([URL]) -> Void) = { [weak self] newFiles in
      guard
        let mainCoordinator = self?.activeSceneDelegate?.mainCoordinator,
        let libraryCoordinator = mainCoordinator.getLibraryCoordinator()
      else {
        return
      }

      libraryCoordinator.processFiles(urls: newFiles)
    }

    let documentsURL = DataManager.getDocumentsFolderURL()
    documentFolderWatcher = DirectoryWatcher.watch(documentsURL)
    documentFolderWatcher?.ignoreDirectories = false
    documentFolderWatcher?.onNewFiles = newFilesCallback

    let sharedFolderURL = DataManager.getSharedFilesFolderURL()
    sharedFolderWatcher = DirectoryWatcher.watch(sharedFolderURL)
    sharedFolderWatcher?.ignoreDirectories = false
    sharedFolderWatcher?.onNewFiles = newFilesCallback

  }

  func requestReview() {
    if let scene = UIApplication.shared.connectedScenes.first(where: {
      $0.activationState == .foregroundActive
    }) as? UIWindowScene {
      SKStoreReviewController.requestReview(in: scene)
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
}
