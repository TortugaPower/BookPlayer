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
import RevenueCat
import StoreKit
import UIKit
import WatchConnectivity

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  static weak var shared: AppDelegate?
  var pendingURLActions = [Action]()

  var window: UIWindow?
  var wasPlayingBeforeInterruption: Bool = false
  var documentFolderWatcher: DirectoryWatcher?
  var sharedFolderWatcher: DirectoryWatcher?

  var dataManager: DataManager?
  var accountService: AccountServiceProtocol?
  var syncService: SyncServiceProtocol?
  var libraryService: LibraryService?
  var playbackService: PlaybackServiceProtocol?
  var playerManager: PlayerManagerProtocol?
  var watchConnectivityService: PhoneWatchConnectivityService?
  var socketService: SocketServiceProtocol?
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

    try? AVAudioSession.sharedInstance().setCategory(
      AVAudioSession.Category.playback,
      mode: AVAudioSession.Mode(rawValue: convertFromAVAudioSessionMode(AVAudioSession.Mode.spokenAudio)),
      options: []
    )

    // register to audio-interruption notifications
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.handleAudioInterruptions(_:)),
      name: AVAudioSession.interruptionNotification,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.messageReceived),
      name: .messageReceived,
      object: nil
    )

    // register for remote events
    self.setupMPRemoteCommands()
    // register document's folder listener
    self.setupDocumentListener()
    // Setup RevenueCat
    self.setupRevenueCat()
    // Setup Sentry
    self.setupSentry()

    return true
  }

  func application(_ application: UIApplication, handle intent: INIntent, completionHandler: @escaping (INIntentResponse) -> Void) {
    ActionParserService.process(intent)

    let response = INPlayMediaIntentResponse(code: .success, userActivity: nil)
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
      syncService = SyncService(libraryService: libraryService)
      AppDelegate.shared?.syncService = syncService
    }

    let playbackService: PlaybackServiceProtocol

    if let sharedPlaybackService = AppDelegate.shared?.playbackService {
      playbackService = sharedPlaybackService
    } else {
      playbackService = PlaybackService(libraryService: libraryService)
      AppDelegate.shared?.playbackService = playbackService
    }

    let socketService: SocketServiceProtocol
    if let sharedSocketService = AppDelegate.shared?.socketService {
      socketService = sharedSocketService
    } else {
      socketService = SocketService()
      AppDelegate.shared?.socketService = socketService
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
        socketService: socketService
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
      watchService: watchService,
      socketService: socketService
    )
  }

  func loadPlayer(
    _ relativePath: String,
    autoplay: Bool,
    showPlayer: (() -> Void)?,
    alertPresenter: AlertPresenter
  ) {
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

    Task { @MainActor in
      guard let libraryItem = await self.libraryService?.getSimpleItem(with: relativePath) else { return }

      var item: PlayableItem?

      do {
        item = try await self.playbackService?.getPlayableItem(from: libraryItem)
      } catch {
        alertPresenter.showAlert("error_title".localized, message: error.localizedDescription, completion: nil)
        return
      }

      guard let item = item else { return }

      playerManager?.load(item, autoplay: autoplay)

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

  func setupRevenueCat() {
    let revenueCatApiKey: String = Bundle.main.configurationValue(for: .revenueCat)
    Purchases.logLevel = .error
    Purchases.configure(withAPIKey: revenueCatApiKey)
  }

  func setupSentry() {
    let sentryDSN: String = Bundle.main.configurationValue(for: .sentryDSN)
    // Create a Sentry client
    SentrySDK.start { options in
      options.dsn = "https://\(sentryDSN)"
      options.debug = false
      options.tracesSampleRate = 0.5
    }
  }

  func setupDocumentListener() {
    let newFilesCallback: (([URL]) -> Void) = { [weak self] newFiles in
      guard
        let activeSceneDelegate = self?.activeSceneDelegate,
        let mainCoordinator = activeSceneDelegate.coordinator.getMainCoordinator(),
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
      UserDefaults.standard.set(true, forKey: Constants.UserDefaults.showPlayer.rawValue)
      return
    }

    if let mainCoordinator = activeSceneDelegate?.coordinator.getMainCoordinator(),
       !mainCoordinator.hasPlayerShown() {
      mainCoordinator.showPlayer()
    }
  }
}

// Helper function inserted by Swift 4.2 migrator.
private func convertFromAVAudioSessionMode(_ input: AVAudioSession.Mode) -> String {
  return input.rawValue
}
