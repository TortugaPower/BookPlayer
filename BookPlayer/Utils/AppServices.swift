//
//  AppServices.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import AppIntents
import BookPlayerKit
import Combine
import CoreData
import Foundation
import StoreKit
import UIKit

@MainActor
final class AppServices: BPLogger {
  static let shared = AppServices()

  let databaseInitializer = DatabaseInitializer()
  var coreServices: CoreServices?

  /// Reference to the task that creates the core services
  var setupCoreServicesTask: Task<(), Error>?
  var errorCoreServicesSetup: Error?

  var pendingURLActions = [Action]()

  let playerState = PlayerState()

  private init() {}

  // MARK: - Core Services Setup

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

  func awaitCoreServices() async throws -> CoreServices {
    _ = await setupCoreServicesTask?.result
    if let error = errorCoreServicesSetup { throw error }
    guard let coreServices else {
      throw NSError(
        domain: "BookPlayer",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Core services not available"]
      )
    }
    return coreServices
  }

  func createCoreServicesIfNeeded(from stack: CoreDataStack) -> CoreServices {
    if let coreServices = self.coreServices {
      return coreServices
    } else {
      let dataManager = DataManager(coreDataStack: stack)
      let accountService = makeAccountService(dataManager: dataManager)
      let audioMetadataService = makeAudioMetadataService()
      let libraryService = makeLibraryService(dataManager: dataManager, audioMetadataService: audioMetadataService)
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

      // Wire up accountService for Watch auth transfer
      watchService.setAccountService(accountService)

      return coreServices
    }
  }

  // MARK: - Convenience Methods

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

    playerState.showPlayer = true
  }

  func requestReview() {
    if let scene = UIApplication.shared.connectedScenes.first(where: {
      $0.activationState == .foregroundActive
    }) as? UIWindowScene {
      AppStore.requestReview(in: scene)
    }
  }

  // MARK: - Background Playback

  /// Loads a book and keeps the app alive via a background task until playback starts.
  func loadAndKeepAlive(
    relativePath: String,
    playerLoaderService: PlayerLoaderService
  ) async throws {
    var bgTaskID: UIBackgroundTaskIdentifier = .invalid
    bgTaskID = UIApplication.shared.beginBackgroundTask(withName: "streaming-playback") {
      UIApplication.shared.endBackgroundTask(bgTaskID)
      bgTaskID = .invalid
    }

    UserDefaults.sharedDefaults.set(
      relativePath,
      forKey: Constants.UserDefaults.sharedWidgetNowPlayingPath
    )

    do {
      try await playerLoaderService.loadPlayer(relativePath, autoplay: true)
    } catch {
      UserDefaults.sharedDefaults.removeObject(
        forKey: Constants.UserDefaults.sharedWidgetNowPlayingPath
      )
      if bgTaskID != .invalid {
        UIApplication.shared.endBackgroundTask(bgTaskID)
        bgTaskID = .invalid
      }
      throw error
    }

    Task { @MainActor [bgTaskID] in
      await playerLoaderService.playerManager.awaitCurrentLoad()
      if bgTaskID != .invalid {
        UIApplication.shared.endBackgroundTask(bgTaskID)
      }
    }
  }

  // MARK: - Factory Methods

  private func makeAccountService(dataManager: DataManager) -> AccountService {
    let service = AccountService()
    service.setup(dataManager: dataManager)
    return service
  }

  private func makeAudioMetadataService() -> AudioMetadataService {
    return AudioMetadataService()
  }

  private func makeLibraryService(dataManager: DataManager, audioMetadataService: AudioMetadataServiceProtocol) -> LibraryService {
    let service = LibraryService()
    service.setup(dataManager: dataManager, audioMetadataService: audioMetadataService)
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
