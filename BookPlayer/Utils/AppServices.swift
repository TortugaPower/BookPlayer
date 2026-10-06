//
//  AppServices.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import AppIntents
import BackgroundTasks
import BookPlayerKit
import Combine
import CoreData
import Foundation
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

  let playerState: PlayerState
  /// Eager, like playerState: CarPlay registers here from connect(), which on a cold launch
  /// into the car runs before CoreServices exist. Its subscription is bound in setup below.
  let promptSurfaceArbiter: PromptSurfaceArbiter

  let reviewPromptService = ReviewPromptService()
  /// Reports parked sync tasks to Sentry; lives as long as the services it observes
  private var syncPauseReporter: SyncPauseReporter?
  /// Keeps book uploads going in the background (a continued processing task)
  let uploadContinuation = UploadContinuationController()
  /// The Wi-Fi-only transfer setting needs to know the current network
  private let networkMonitor = NetworkMonitor()

  private init() {
    let playerState = PlayerState()
    self.playerState = playerState
    self.promptSurfaceArbiter = PromptSurfaceArbiter(playerState: playerState)
  }

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
      MigrationPlan.injectedCoreDataContext = stack.backgroundContext
      let accountService = makeAccountService(dataManager: dataManager)
      let audioMetadataService = makeAudioMetadataService()
      let libraryService = makeLibraryService(dataManager: dataManager, audioMetadataService: audioMetadataService)
      let tasksDataManager = TasksDataManager()
      let syncQueueService = makeSyncQueueService(
        libraryService: libraryService,
        getAccessLevel: { accountService.getAccessLevel() },
        verifySyncEntitlement: { await accountService.refreshSyncEntitlement() },
        tasksDataManager: tasksDataManager,
        dataManager: dataManager
      )
      // Not in the unit-test host: tests post `.syncTaskPaused` themselves, and those must
      // never reach the real Sentry project
      if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
        syncPauseReporter = SyncPauseReporter(syncQueueService: syncQueueService)
      }
      let syncService = makeSyncService(
        accountService: accountService,
        libraryService: libraryService,
        syncQueueService: syncQueueService
      )
      let playbackService = makePlaybackService(libraryService: libraryService)
      let playerManager = PlayerManager(
        libraryService: libraryService,
        playbackService: playbackService,
        syncService: syncService,
        speedService: SpeedService(libraryService: libraryService),
        shakeMotionService: ShakeMotionService(),
        widgetReloadService: WidgetReloadService(),
        hasStreamingEnabled: { accountService.hasStreamingEnabled() },
        /// Already on main: `PlayerManager` routes every failure through `presentOnMain`.
        presentFailure: { [promptSurfaceArbiter] failure in
          promptSurfaceArbiter.routeFailure(failure)
        }
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
      let hardcoverService = makeHardcoverService(libraryService: libraryService, syncService: syncService)

      let preferencesService = PreferencesSyncService()
      preferencesService.setup(
        accountService: accountService,
        libraryService: libraryService
      )
      libraryService.preferencesService = preferencesService
      Task { await preferencesService.bootstrap() }

      let mediaServerChapterService = MediaServerChapterRefreshService()
      mediaServerChapterService.setup(libraryService: libraryService, accountService: accountService)

      let coreServices = CoreServices(
        accountService: accountService,
        dataManager: dataManager,
        hardcoverService: hardcoverService,
        libraryService: libraryService,
        playbackService: playbackService,
        playerLoaderService: playerLoaderService,
        playerManager: playerManager,
        preferencesService: preferencesService,
        syncService: syncService,
        syncQueueService: syncQueueService,
        mediaServerChapterService: mediaServerChapterService,
        watchService: watchService
      )

      self.coreServices = coreServices
      setupUploadContinuation(syncQueueService: syncQueueService)

      // Wire up accountService for Watch auth transfer
      watchService.setAccountService(accountService)

      return coreServices
    }
  }

  private func setupUploadContinuation(syncQueueService: SyncQueueService) {
    let networkMonitor = networkMonitor
    uploadContinuation.setup(dependencies: .init(
      canUpload: { syncQueueService.serverLanesEnabled && syncQueueService.accessPolicy[.uploadFile] == true },
      // Wi-Fi-only means "not over cellular", as the non-cellular session does (wired
      // Ethernet counts)
      networkAllowsUploads: {
        UserDefaults.standard.bool(forKey: Constants.UserDefaults.allowCellularData)
          || (networkMonitor.isConnected && !networkMonitor.isConnectedViaCellular)
      },
      isForeground: { UIApplication.shared.applicationState == .active },
      pendingUploads: { await syncQueueService.pendingBookUploads() },
      submit: { request in
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
          AppDelegate.submitBackgroundTask(request) { error in
            if let error {
              continuation.resume(throwing: error)
            } else {
              continuation.resume()
            }
          }
        }
      },
      hasPendingRequest: {
        await BGTaskScheduler.shared.pendingTaskRequests()
          .contains { $0.identifier == UploadContinuationController.identifier }
      },
      queueChanges: { syncQueueService.observeQueueCounts() },
      currentCounts: { syncQueueService.queueCounts }
    ))
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

  private func makeLibraryService(
    dataManager: DataManager,
    audioMetadataService: AudioMetadataServiceProtocol
  ) -> LibraryService {
    let service = LibraryService()
    service.setup(dataManager: dataManager, audioMetadataService: audioMetadataService)
    return service
  }

  private func makeSyncService(
    accountService: AccountService,
    libraryService: LibraryService,
    syncQueueService: SyncQueueService
  ) -> SyncService {
    let service = SyncService()
    service.setup(
      isActive: accountService.hasSyncEnabled(),
      libraryService: libraryService,
      accountService: accountService,
      syncQueueService: syncQueueService,
      runsMissingItemsPass: true
    )
    return service
  }

  private func makeSyncQueueService(
    libraryService: LibraryService,
    getAccessLevel: @escaping () -> AccessLevel,
    verifySyncEntitlement: @escaping () async -> Bool?,
    tasksDataManager: TasksDataManager,
    dataManager: DataManager
  ) -> SyncQueueService {
    let service = SyncQueueService()
    service.setup(
      libraryService: libraryService,
      getAccessLevel: getAccessLevel,
      verifySyncEntitlement: verifySyncEntitlement,
      tasksDataManager: tasksDataManager,
      networkClient: NetworkClient(),
      dataManager: dataManager
    )
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

  private func makeHardcoverService(libraryService: LibraryService, syncService: SyncService) -> HardcoverService {
    let service = HardcoverService()
    service.setup(libraryService: libraryService, syncService: syncService)
    return service
  }
}
