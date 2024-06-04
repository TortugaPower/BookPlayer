//
// AppDelegate.swift
// BookPlayer
//
// Created by Gianni Carlo on 7/1/16.
// Copyright © 2016 Tortuga Power. All rights reserved.
//

import AVFoundation
import BackgroundTasks
import BookPlayerKit
import Combine
import CoreData
import DirectoryWatcher
import Intents
import MediaPlayer
import Sentry
import RealmSwift
import RevenueCat
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

  var dataManager: DataManager?
  var accountService: AccountServiceProtocol?
  var syncService: SyncServiceProtocol?
  var libraryService: LibraryService?
  var playbackService: PlaybackServiceProtocol?
  var playerManager: PlayerManagerProtocol?
  var watchConnectivityService: PhoneWatchConnectivityService?
  /// Internal property used as a fallback in ``activeSceneDelegate``
  var lastSceneToResignActive: SceneDelegate?
  /// Access the current (or last) active scene delegate to present VCs or alerts
  var activeSceneDelegate: SceneDelegate? {
    if let scene = UIApplication.shared.connectedScenes.first(
      where: { $0.activationState == .foregroundActive }
    ) as? UIWindowScene,
       let delegate = scene.delegate as? SceneDelegate {
      return delegate
    } else {
      return lastSceneToResignActive
    }
  }
  /// Reference for observers
  private var crashReportsAccessObserver: NSKeyValueObservation?
  private var sharedWidgetActionURLObserver: NSKeyValueObservation?
  /// Background refresh task identifier
  private lazy var refreshTaskIdentifier = "\(Bundle.main.configurationString(for: .bundleIdentifier)).background.refresh"

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
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
    // Setup observer for interactive widgets
    self.setupSharedWidgetActionObserver()

    return true
  }

  func application(_ application: UIApplication, handle intent: INIntent, completionHandler: @escaping (INIntentResponse) -> Void) {
    let response: INPlayMediaIntentResponse
    do {
      try ActionParserService.process(intent)
      response = INPlayMediaIntentResponse(code: .success, userActivity: nil)
    } catch {
      response = INPlayMediaIntentResponse(code: .failure, userActivity: nil)
    }
    completionHandler(response)
  }

  // swiftlint:disable:next function_body_length
  func createCoreServicesIfNeeded(from stack: CoreDataStack) -> CoreServices {
    let dataManager: DataManager

    if let sharedDataManager = AppDelegate.shared?.dataManager {
      dataManager = sharedDataManager
    } else {
      dataManager = DataManager(coreDataStack: stack)
      AppDelegate.shared?.dataManager = dataManager
    }

    let accountService: AccountServiceProtocol

    if let sharedAccountService = AppDelegate.shared?.accountService {
      accountService = sharedAccountService
    } else {
      accountService = AccountService(dataManager: dataManager)
      AppDelegate.shared?.accountService = accountService
    }

    let libraryService: LibraryService

    if let sharedLibraryService = AppDelegate.shared?.libraryService {
      libraryService = sharedLibraryService
    } else {
      libraryService = LibraryService(dataManager: dataManager)
      AppDelegate.shared?.libraryService = libraryService
    }

    let syncService: SyncServiceProtocol

    if let sharedSyncService = AppDelegate.shared?.syncService {
      syncService = sharedSyncService
    } else {
      syncService = SyncService(
        isActive: accountService.hasSyncEnabled(),
        libraryService: libraryService
      )
      AppDelegate.shared?.syncService = syncService
    }

    let playbackService: PlaybackServiceProtocol

    if let sharedPlaybackService = AppDelegate.shared?.playbackService {
      playbackService = sharedPlaybackService
    } else {
      playbackService = PlaybackService(libraryService: libraryService)
      AppDelegate.shared?.playbackService = playbackService
    }

    let playerManager: PlayerManagerProtocol

    if let sharedPlayerManager = AppDelegate.shared?.playerManager {
      playerManager = sharedPlayerManager
    } else {
      playerManager = PlayerManager(
        libraryService: libraryService,
        playbackService: playbackService,
        syncService: syncService,
        speedService: SpeedService(libraryService: libraryService),
        shakeMotionService: ShakeMotionService(),
        widgetReloadService: WidgetReloadService()
      )
      AppDelegate.shared?.playerManager = playerManager
    }

    let watchService: PhoneWatchConnectivityService

    if let sharedWatchService = AppDelegate.shared?.watchConnectivityService {
      watchService = sharedWatchService
    } else {
      watchService = PhoneWatchConnectivityService(
        libraryService: libraryService,
        playbackService: playbackService,
        playerManager: playerManager
      )
      AppDelegate.shared?.watchConnectivityService = watchService
    }

    return CoreServices(
      dataManager: dataManager,
      accountService: accountService,
      syncService: syncService,
      libraryService: libraryService,
      playbackService: playbackService,
      playerManager: playerManager,
      watchService: watchService
    )
  }

  func loadPlayer(
    _ relativePath: String,
    autoplay: Bool,
    showPlayer: (() -> Void)?,
    alertPresenter: AlertPresenter,
    recordAsLastBook: Bool = true
  ) {
    Task { @MainActor in
      let fileURL = DataManager.getProcessedFolderURL().appendingPathComponent(relativePath)

      if syncService?.isActive == false,
         !FileManager.default.fileExists(atPath: fileURL.path) {
        alertPresenter.showAlert("file_missing_title".localized, message: "\("file_missing_description".localized)\n\(fileURL.lastPathComponent)", completion: nil)
        return
      }

      // Only load if loaded book is a different one
      if playerManager?.hasLoadedBook() == true,
         relativePath == playerManager?.currentItem?.relativePath {
        if autoplay {
          playerManager?.play()
        }
        showPlayer?()
        return
      }

      guard let libraryItem = self.libraryService?.getSimpleItem(with: relativePath) else { return }

      var item: PlayableItem?

      do {
        /// If the selected item is a bound book, check that the contents are loaded
        if syncService?.isActive == true,
           libraryItem.type == .bound,
           let contents = libraryService?.getMaxItemsCount(at: relativePath),
           contents == 0 {
          _ = try await syncService?.syncListContents(at: relativePath)
        }

        item = try self.playbackService?.getPlayableItem(from: libraryItem)
      } catch {
        alertPresenter.showAlert("error_title".localized, message: error.localizedDescription, completion: nil)
        return
      }

      guard let item = item else { return }

      playerManager?.load(item, autoplay: autoplay)

      if recordAsLastBook {
        await MainActor.run {
          libraryService?.setLibraryLastBook(with: item.relativePath)
        }
      }

      showPlayer?()
    }
  }

  @objc func messageReceived(_ notification: Notification) {
    guard
      let message = notification.userInfo as? [String: Any],
      let action = CommandParser.parse(message) else {
      return
    }

    DispatchQueue.main.async {
      ActionParserService.handleAction(action)
    }
  }

  override func accessibilityPerformMagicTap() -> Bool {
    guard
      let playerManager = self.playerManager,
      playerManager.currentItem != nil
    else {
      UIAccessibility.post(notification: .announcement, argument: "voiceover_no_title".localized)
      return false
    }

    playerManager.playPause()
    return true
  }

  func setupMPRemoteCommands() {
    self.setupMPPlaybackRemoteCommands()
    self.setupMPSkipRemoteCommands()
  }

  func setupMPPlaybackRemoteCommands() {
    // Play / Pause
    MPRemoteCommandCenter.shared().togglePlayPauseCommand.isEnabled = true
    MPRemoteCommandCenter.shared().togglePlayPauseCommand.addTarget { [weak self] (_) -> MPRemoteCommandHandlerStatus in
      guard let playerManager = self?.playerManager else { return .commandFailed }

      let wasPlaying = playerManager.isPlaying
      playerManager.playPause()

      if wasPlaying,
         UIApplication.shared.applicationState == .background {
        self?.scheduleAppRefresh()
      }
      return .success
    }

    MPRemoteCommandCenter.shared().playCommand.isEnabled = true
    MPRemoteCommandCenter.shared().playCommand.addTarget { [weak self] (_) -> MPRemoteCommandHandlerStatus in
      guard let playerManager = self?.playerManager else { return .commandFailed }

      playerManager.play()
      return .success
    }

    MPRemoteCommandCenter.shared().pauseCommand.isEnabled = true
    MPRemoteCommandCenter.shared().pauseCommand.addTarget { [weak self] (_) -> MPRemoteCommandHandlerStatus in
      guard let playerManager = self?.playerManager else { return .commandFailed }

      playerManager.pause()

      if UIApplication.shared.applicationState == .background {
        self?.scheduleAppRefresh()
      }

      return .success
    }

    MPRemoteCommandCenter.shared().changePlaybackPositionCommand.isEnabled = true
    MPRemoteCommandCenter.shared().changePlaybackPositionCommand.addTarget { [weak self] remoteEvent in
      guard
        let playerManager = self?.playerManager,
        let currentItem = playerManager.currentItem,
        let event = remoteEvent as? MPChangePlaybackPositionCommandEvent
      else { return .commandFailed }

      var newTime = event.positionTime

      if UserDefaults.sharedDefaults.bool(forKey: Constants.UserDefaults.chapterContextEnabled),
         let currentChapter = currentItem.currentChapter {
        newTime += currentChapter.start
      }

      playerManager.jumpTo(newTime, recordBookmark: true)

      return .success
    }
  }

  // For now, seek forward/backward and next/previous track perform the same function
  func setupMPSkipRemoteCommands() {
    // Forward
    MPRemoteCommandCenter.shared().skipForwardCommand.preferredIntervals = [NSNumber(value: PlayerManager.forwardInterval)]
    MPRemoteCommandCenter.shared().skipForwardCommand.addTarget { [weak self] (_) -> MPRemoteCommandHandlerStatus in
      guard let playerManager = self?.playerManager else { return .commandFailed }

      playerManager.forward()
      return .success
    }

    MPRemoteCommandCenter.shared().nextTrackCommand.addTarget { [weak self] (_) -> MPRemoteCommandHandlerStatus in
      guard let playerManager = self?.playerManager else { return .commandFailed }

      playerManager.forward()
      return .success
    }

    MPRemoteCommandCenter.shared().seekForwardCommand.addTarget { [weak self] (commandEvent) -> MPRemoteCommandHandlerStatus in
      guard let cmd = commandEvent as? MPSeekCommandEvent, cmd.type == .endSeeking else {
        return .success
      }

      guard let playerManager = self?.playerManager else { return .success }

      // End seeking
      playerManager.forward()
      return .success
    }

    // Rewind
    MPRemoteCommandCenter.shared().skipBackwardCommand.preferredIntervals = [NSNumber(value: PlayerManager.rewindInterval)]
    MPRemoteCommandCenter.shared().skipBackwardCommand.addTarget { [weak self] (_) -> MPRemoteCommandHandlerStatus in
      guard let playerManager = self?.playerManager else { return .commandFailed }

      playerManager.rewind()
      return .success
    }

    MPRemoteCommandCenter.shared().previousTrackCommand.addTarget { [weak self] (_) -> MPRemoteCommandHandlerStatus in
      guard let playerManager = self?.playerManager else { return .commandFailed }

      playerManager.rewind()
      return .success
    }

    MPRemoteCommandCenter.shared().seekBackwardCommand.addTarget { [weak self] (commandEvent) -> MPRemoteCommandHandlerStatus in
      guard let cmd = commandEvent as? MPSeekCommandEvent, cmd.type == .endSeeking else {
        return .success
      }

      guard let playerManager = self?.playerManager else { return .success }

      // End seeking
      playerManager.rewind()
      return .success
    }
  }

  func setupRevenueCat() {
    let revenueCatApiKey: String = Bundle.main.configurationValue(for: .revenueCat)
    Purchases.logLevel = .error
    Purchases.configure(withAPIKey: revenueCatApiKey)
  }

  /// Setup observer for user preference, and setup Sentry based on initial value
  func setupSentry() {
    let userDefaults = UserDefaults.standard
    crashReportsAccessObserver = userDefaults.observe(\.userSettingsCrashReportsDisabled) { [weak self] object, _ in
      self?.handleSentryPreference(isDisabled: object.userSettingsCrashReportsDisabled)
    }

    handleSentryPreference(
      isDisabled: userDefaults.bool(forKey: Constants.UserDefaults.crashReportsDisabled)
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

  func setupSharedWidgetActionObserver() {
    let sharedDefaults = UserDefaults.sharedDefaults

    if let actionURL = sharedDefaults.sharedWidgetActionURL {
      ActionParserService.process(actionURL)
      sharedDefaults.removeObject(forKey: Constants.UserDefaults.sharedWidgetActionURL)
    }

    sharedWidgetActionURLObserver = sharedDefaults.observe(\.sharedWidgetActionURL) { defaults, _ in
      DispatchQueue.main.async {
        guard let actionURL = defaults.sharedWidgetActionURL else { return }

        ActionParserService.process(actionURL)
        sharedDefaults.removeObject(forKey: Constants.UserDefaults.sharedWidgetActionURL)
      }
    }
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
    if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
      SKStoreReviewController.requestReview(in: scene)
    }
  }

  func playLastBook() {
    guard
      let playerManager,
      playerManager.hasLoadedBook()
    else {
      UserDefaults.standard.set(true, forKey: Constants.UserActivityPlayback)
      return
    }

    playerManager.play()
  }

  func showPlayer() {
    guard
      let playerManager,
      playerManager.hasLoadedBook()
    else {
      UserDefaults.standard.set(true, forKey: Constants.UserDefaults.showPlayer)
      return
    }

    if let mainCoordinator = activeSceneDelegate?.mainCoordinator,
       !mainCoordinator.hasPlayerShown() {
      mainCoordinator.showPlayer()
    }
  }
}

// MARK: - Background tasks

extension AppDelegate {

  func setupBackgroundRefreshTasks() {
    NotificationCenter.default.addObserver(
      forName: UIApplication.didEnterBackgroundNotification,
      object: nil, queue: nil) { _ in
        if self.playerManager?.isPlaying != true {
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
    guard let syncService else { return }

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
