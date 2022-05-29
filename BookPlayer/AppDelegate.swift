//
// AppDelegate.swift
// BookPlayer
//
// Created by Gianni Carlo on 7/1/16.
// Copyright © 2016 Tortuga Power. All rights reserved.
//

import AVFoundation
import BookPlayerKit
import Combine
import CoreData
import DirectoryWatcher
import Intents
import MediaPlayer
import Sentry
import SwiftyStoreKit
import UIKit
import WatchConnectivity

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  static weak var shared: AppDelegate?
  var pendingURLActions = [Action]()

  var window: UIWindow?
  var wasPlayingBeforeInterruption: Bool = false
  var watcher: DirectoryWatcher?

  var dataManager: DataManager?
  var libraryService: LibraryServiceProtocol?
  var playbackService: PlaybackServiceProtocol?
  var playerManager: PlayerManagerProtocol?
  var watchConnectivityService: PhoneWatchConnectivityService? {
    didSet {
      if oldValue == nil {
        watchConnectivityService?.startSession()
      }
    }
  }

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    Self.shared = self
    // Override point for customization after application launch.
    let defaults: UserDefaults = UserDefaults.standard

    // Perfrom first launch setup
    if !defaults.bool(forKey: Constants.UserDefaults.completedFirstLaunch.rawValue) {
      // Set default settings
      defaults.set(true, forKey: Constants.UserDefaults.chapterContextEnabled.rawValue)
      defaults.set(true, forKey: Constants.UserDefaults.smartRewindEnabled.rawValue)
      defaults.set(true, forKey: Constants.UserDefaults.completedFirstLaunch.rawValue)
    }

    try? AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback, mode: AVAudioSession.Mode(rawValue: convertFromAVAudioSessionMode(AVAudioSession.Mode.spokenAudio)), options: [])

    // register to audio-interruption notifications
    NotificationCenter.default.addObserver(self, selector: #selector(self.handleAudioInterruptions(_:)), name: AVAudioSession.interruptionNotification, object: nil)

    NotificationCenter.default.addObserver(self, selector: #selector(self.messageReceived), name: .messageReceived, object: nil)

    // register for remote events
    self.setupMPRemoteCommands()
    // register document's folder listener
    self.setupDocumentListener()
    // setup store required listeners
    self.setupStoreListener()

    // Create a Sentry client
    SentrySDK.start { options in
      options.dsn = "https://23b4d02f7b044c10adb55a0cc8de3881@sentry.io/1414296"
      options.debug = false
    }

    return true
  }

  func application(_ application: UIApplication, handle intent: INIntent, completionHandler: @escaping (INIntentResponse) -> Void) {
    ActionParserService.process(intent)

    let response = INPlayMediaIntentResponse(code: .success, userActivity: nil)
    completionHandler(response)
  }

  func loadPlayer(
    _ relativePath: String,
    autoplay: Bool,
    showPlayer: (() -> Void)?,
    alertPresenter: AlertPresenter
  ) {
    let fileURL = DataManager.getProcessedFolderURL().appendingPathComponent(relativePath)
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      alertPresenter.showAlert("file_missing_title".localized, message: "\("file_missing_description".localized)\n\(fileURL.lastPathComponent)", completion: nil)
      return
    }

    // Only load if loaded book is a different one
    guard relativePath != self.playerManager?.currentItem?.relativePath else {
      showPlayer?()
      return
    }

    // Only load if loaded book is a different one
    guard let libraryItem = self.libraryService?.getItem(with: relativePath) else { return }

    var item: PlayableItem?

    do {
      item = try self.playbackService?.getPlayableItem(from: libraryItem)
    } catch {
      alertPresenter.showAlert("error_title".localized, message: error.localizedDescription, completion: nil)
      return
    }

    guard let item = item else { return }

    var subscription: AnyCancellable?

    subscription = NotificationCenter.default.publisher(for: .bookReady, object: nil)
      .sink(receiveValue: { [weak self, showPlayer, autoplay] notification in
        guard
          let userInfo = notification.userInfo,
          let loaded = userInfo["loaded"] as? Bool,
          loaded == true
        else {
          subscription?.cancel()
          return
        }

        showPlayer?()

        if autoplay {
          self?.playerManager?.play()
        }

        subscription?.cancel()
      })

    self.playerManager?.load(item)
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

  // Playback may be interrupted by calls. Handle pause
  @objc func handleAudioInterruptions(_ notification: Notification) {
    guard
      let userInfo = notification.userInfo,
      let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
      let type = AVAudioSession.InterruptionType(rawValue: typeValue),
      let playerManager = self.playerManager
    else {
      return
    }

    switch type {
    case .began:
      if playerManager.isPlaying {
        playerManager.pause(fade: false)
      }
    case .ended:
      guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
        return
      }

      let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
      if options.contains(.shouldResume) {
        playerManager.play()
      }
    @unknown default:
      break
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

      playerManager.playPause()
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

      playerManager.pause(fade: false)
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

      if UserDefaults.standard.bool(forKey: Constants.UserDefaults.chapterContextEnabled.rawValue),
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

  func setupDocumentListener() {
    let documentsUrl = DataManager.getDocumentsFolderURL()

    self.watcher = DirectoryWatcher.watch(documentsUrl)
    self.watcher?.ignoreDirectories = false

    self.watcher?.onNewFiles = { newFiles in
      guard
        let mainCoordinator = SceneDelegate.shared?.coordinator.getMainCoordinator(),
        let libraryCoordinator = mainCoordinator.getLibraryCoordinator()
      else {
        return
      }

      libraryCoordinator.processFiles(urls: newFiles)
    }
  }

  func setupStoreListener() {
    SwiftyStoreKit.completeTransactions(atomically: true) { purchases in
      for purchase in purchases {
        guard purchase.transaction.transactionState == .purchased
                || purchase.transaction.transactionState == .restored
        else { continue }

        UserDefaults.standard.set(true, forKey: Constants.UserDefaults.donationMade.rawValue)
        NotificationCenter.default.post(name: .donationMade, object: nil)

        if purchase.needsFinishTransaction {
          SwiftyStoreKit.finishTransaction(purchase.transaction)
        }
      }
    }

    SwiftyStoreKit.shouldAddStorePaymentHandler = { _, _ in
      true
    }
  }
}

// Helper function inserted by Swift 4.2 migrator.
private func convertFromAVAudioSessionMode(_ input: AVAudioSession.Mode) -> String {
  return input.rawValue
}
