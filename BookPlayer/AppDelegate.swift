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

  var window: UIWindow?

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
    AppServices.shared.setupCoreServices()

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
      let playerManager = AppServices.shared.coreServices?.playerManager,
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

  // MARK: - Media Player Remote Commands

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
    center.togglePlayPauseCommand.addTarget { (_) -> MPRemoteCommandHandlerStatus in
      guard let playerManager = AppServices.shared.coreServices?.playerManager else {
        return .commandFailed
      }

      let wasPlaying = playerManager.isPlaying
      playerManager.playPause()

      if wasPlaying,
        UIApplication.shared.applicationState == .background
      {
        self.scheduleAppRefresh()
      }
      return .success
    }

    center.playCommand.isEnabled = true
    center.playCommand.addTarget { (_) -> MPRemoteCommandHandlerStatus in
      guard let playerManager = AppServices.shared.coreServices?.playerManager else {
        return .commandFailed
      }

      let wasPlaying = playerManager.isPlaying
      playerManager.playPause()

      if wasPlaying,
        UIApplication.shared.applicationState == .background
      {
        self.scheduleAppRefresh()
      }
      return .success
    }

    center.pauseCommand.isEnabled = true
    center.pauseCommand.addTarget { (_) -> MPRemoteCommandHandlerStatus in
      guard let playerManager = AppServices.shared.coreServices?.playerManager else {
        return .commandFailed
      }

      playerManager.pause()

      if UIApplication.shared.applicationState == .background {
        self.scheduleAppRefresh()
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
    center.changePlaybackPositionCommand.addTarget { remoteEvent in
      guard
        let playerManager = AppServices.shared.coreServices?.playerManager,
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
    if PlayerManager.isForwardChapterSkip {
      center.skipForwardCommand.isEnabled = false
    } else {
      center.skipForwardCommand.preferredIntervals = [NSNumber(value: PlayerManager.forwardInterval)]
    }
    center.skipForwardCommand.addTarget { (_) -> MPRemoteCommandHandlerStatus in
      guard let playerManager = AppServices.shared.coreServices?.playerManager else { return .commandFailed }

      playerManager.forward()
      return .success
    }

    center.nextTrackCommand.addTarget { (_) -> MPRemoteCommandHandlerStatus in
      guard let playerManager = AppServices.shared.coreServices?.playerManager else { return .commandFailed }

      playerManager.forward()
      return .success
    }

    center.seekForwardCommand.addTarget { (commandEvent) -> MPRemoteCommandHandlerStatus in
      guard let cmd = commandEvent as? MPSeekCommandEvent,
        cmd.type == .endSeeking
      else {
        return .success
      }

      guard let playerManager = AppServices.shared.coreServices?.playerManager else { return .success }

      // End seeking
      playerManager.forward()
      return .success
    }

    // Rewind
    if PlayerManager.isRewindChapterSkip {
      center.skipBackwardCommand.isEnabled = false
    } else {
      center.skipBackwardCommand.preferredIntervals = [NSNumber(value: PlayerManager.rewindInterval)]
    }
    center.skipBackwardCommand.addTarget { (_) -> MPRemoteCommandHandlerStatus in
      guard let playerManager = AppServices.shared.coreServices?.playerManager else { return .commandFailed }

      playerManager.rewind()
      return .success
    }

    center.previousTrackCommand.addTarget { (_) -> MPRemoteCommandHandlerStatus in
      guard let playerManager = AppServices.shared.coreServices?.playerManager else { return .commandFailed }

      playerManager.rewind()
      return .success
    }

    center.seekBackwardCommand.addTarget { (commandEvent) -> MPRemoteCommandHandlerStatus in
      guard
        let cmd = commandEvent as? MPSeekCommandEvent,
        cmd.type == .endSeeking
      else {
        return .success
      }

      guard let playerManager = AppServices.shared.coreServices?.playerManager else { return .success }

      // End seeking
      playerManager.rewind()
      return .success
    }
  }

  // MARK: - Third-party SDKs

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
}

// MARK: - Background tasks

extension AppDelegate {

  func setupBackgroundRefreshTasks() {
    NotificationCenter.default.addObserver(
      forName: UIApplication.didEnterBackgroundNotification,
      object: nil,
      queue: nil
    ) { _ in
      Task { @MainActor in
        if AppServices.shared.coreServices?.playerManager.isPlaying != true {
          self.scheduleAppRefresh()
        }
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
    guard let syncService = AppServices.shared.coreServices?.syncService else { return }

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