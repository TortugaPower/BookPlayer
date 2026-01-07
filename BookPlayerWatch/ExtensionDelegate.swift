//
//  ExtensionDelegate.swift
//  BookPlayerWatch Extension
//
//  Created by Gianni Carlo on 4/25/19.
//  Copyright © 2019 BookPlayer LLC. All rights reserved.
//

import BookPlayerWatchKit
import RevenueCat
import SwiftUI
import TipKit
import WatchKit
import MediaPlayer

class ExtensionDelegate: NSObject, WKApplicationDelegate, ObservableObject {
  static var contextManager = ContextManager()
  let databaseInitializer = DatabaseInitializer()
  @Published var coreServices: CoreServices?

  /// Reference to the task that creates the core services
  var setupCoreServicesTask: Task<(), Error>?
  var errorCoreServicesSetup: Error?

  func applicationDidFinishLaunching() {
    setupRevenueCat()
    setupCoreServices()
    setupMPRemoteCommands()
    setupTips()
  }
  
  func setupTips() {
    if #available(watchOS 10.0, *) {
      try? Tips.configure()
    }
  }

  func setupRevenueCat() {
    let revenueCatApiKey: String = Bundle.main.configurationValue(
      for: .revenueCat
    )
    Purchases.logLevel = .error
    let rcUserId = UserDefaults.sharedDefaults.string(forKey: "rcUserId")
    Purchases.configure(withAPIKey: revenueCatApiKey, appUserID: rcUserId)
    Purchases.shared.delegate = self
  }

  func setupCoreServices() {
    setupCoreServicesTask = Task {
      do {
        let stack = try await databaseInitializer.loadCoreDataStack()
        let coreServices = createCoreServicesIfNeeded(from: stack)
        self.coreServices = coreServices
        /// setup blank account if needed
        guard !coreServices.accountService.hasAccount() else { return }
        coreServices.accountService.createAccount(donationMade: false)
      } catch {
        errorCoreServicesSetup = error
      }
    }
  }

  func createCoreServicesIfNeeded(from stack: CoreDataStack) -> CoreServices {
    if let coreServices = self.coreServices {
      return coreServices
    } else {
      let dataManager = DataManager(coreDataStack: stack)
      let accountService = AccountService()
      accountService.setup(dataManager: dataManager)
      let audioMetadataService = AudioMetadataService()
      let libraryService = LibraryService()
      libraryService.setup(dataManager: dataManager, audioMetadataService: audioMetadataService)
      let syncService = SyncService()
      syncService.setup(
        isActive: accountService.hasSyncEnabled(),
        libraryService: libraryService
      )
      let playbackService = PlaybackService()
      playbackService.setup(libraryService: libraryService)
      let playerManager = PlayerManager(
        libraryService: libraryService,
        playbackService: playbackService,
        syncService: syncService,
        speedService: SpeedService(libraryService: libraryService),
        widgetReloadService: WidgetReloadService()
      )
      let playerLoaderService = PlayerLoaderService()
      playerLoaderService.setup(
        syncService: syncService,
        libraryService: libraryService,
        playbackService: playbackService,
        playerManager: playerManager
      )
      let coreServices = CoreServices(
        dataManager: dataManager,
        accountService: accountService,
        syncService: syncService,
        libraryService: libraryService,
        playbackService: playbackService,
        playerManager: playerManager,
        playerLoaderService: playerLoaderService
      )

      self.coreServices = coreServices

      return coreServices
    }
  }

  /// For some reason this never gets called
  func handleRemoteNowPlayingActivity() {}

  func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
    // Sent when the system needs to launch the application in the background to process tasks. Tasks arrive in a set, so loop through and process each one.
    for task in backgroundTasks {
      // Use a switch statement to check the task type
      switch task {
      case let backgroundTask as WKApplicationRefreshBackgroundTask:
        // Be sure to complete the background task once you’re done.
        backgroundTask.setTaskCompletedWithSnapshot(false)
      case let snapshotTask as WKSnapshotRefreshBackgroundTask:
        // Snapshot tasks have a unique completion call, make sure to set your expiration date
        snapshotTask.setTaskCompleted(
          restoredDefaultState: true,
          estimatedSnapshotExpiration: Date.distantFuture,
          userInfo: nil
        )
      case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
        // Be sure to complete the connectivity task once you’re done.
        connectivityTask.setTaskCompletedWithSnapshot(false)
      case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
        // Be sure to complete the URL session task once you’re done.
        urlSessionTask.setTaskCompletedWithSnapshot(false)
      case let relevantShortcutTask as WKRelevantShortcutRefreshBackgroundTask:
        // Be sure to complete the relevant-shortcut task once you're done.
        relevantShortcutTask.setTaskCompletedWithSnapshot(false)
      case let intentDidRunTask as WKIntentDidRunRefreshBackgroundTask:
        // Be sure to complete the intent-did-run task once you're done.
        intentDidRunTask.setTaskCompletedWithSnapshot(false)
      default:
        // make sure to complete unhandled task types
        task.setTaskCompletedWithSnapshot(false)
      }
    }
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

      playerManager.playPause()

      return .success
    }

    center.playCommand.isEnabled = true
    center.playCommand.addTarget { [weak self] (_) -> MPRemoteCommandHandlerStatus in
      guard let playerManager = self?.coreServices?.playerManager else {
        return .commandFailed
      }

      playerManager.playPause()

      return .success
    }

    center.pauseCommand.isEnabled = true
    center.pauseCommand.addTarget { [weak self] (_) -> MPRemoteCommandHandlerStatus in
      guard let playerManager = self?.coreServices?.playerManager else {
        return .commandFailed
      }

      playerManager.pause()

      return .success
    }

    center.changePlaybackPositionCommand.isEnabled = true
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
}

extension ExtensionDelegate: PurchasesDelegate {
  func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
    coreServices?.updateSyncEnabled(customerInfo.entitlements.all["pro"]?.isActive == true)
  }
}
