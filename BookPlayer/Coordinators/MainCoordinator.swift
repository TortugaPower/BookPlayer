//
//  MainCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/9/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import RevenueCat
import SwiftUI
import Themeable
import UIKit

@MainActor
class MainCoordinator: NSObject {
  var mainController: UIViewController?

  let importManager: ImportManager
  let playerManager: PlayerManager
  let playerLoaderService: PlayerLoaderService
  let singleFileDownloadService: SingleFileDownloadService
  let libraryService: LibraryService
  let playbackService: PlaybackService
  let listSyncRefreshService: ListSyncRefreshService
  let accountService: AccountService
  var syncService: SyncService
  let watchConnectivityService: PhoneWatchConnectivityService
  let jellyfinConnectionService: JellyfinConnectionService
  let audiobookshelfConnectionService: AudiobookShelfConnectionService
  let syncQueueService: SyncQueueService
  let hardcoverService: HardcoverService
  let preferencesService: PreferencesSyncService

  var playerState: PlayerState { AppServices.shared.playerState }

  /// Reference to know if the import screen is already being shown (or in the process of showing)
  weak var importCoordinator: ImportCoordinator?
  let navigationController: UINavigationController

  private var disposeBag = Set<AnyCancellable>()

  init(
    navigationController: UINavigationController,
    coreServices: CoreServices
  ) {
    self.navigationController = navigationController
    self.libraryService = coreServices.libraryService
    self.importManager = ImportManager(libraryService: coreServices.libraryService)
    self.accountService = coreServices.accountService
    self.syncService = coreServices.syncService
    self.playbackService = coreServices.playbackService
    self.playerManager = coreServices.playerManager
    self.playerLoaderService = coreServices.playerLoaderService
    self.listSyncRefreshService = ListSyncRefreshService(
      playerManager: playerManager,
      syncService: syncService,
      playerLoaderService: coreServices.playerLoaderService,
      preferencesService: coreServices.preferencesService,
      chapterRefreshService: coreServices.mediaServerChapterService
    )
    self.syncQueueService = coreServices.syncQueueService
    self.singleFileDownloadService = SingleFileDownloadService(networkClient: NetworkClient())
    self.watchConnectivityService = coreServices.watchService
    let jellyfinService = JellyfinConnectionService()
    jellyfinService.setup()
    self.jellyfinConnectionService = jellyfinService

    let audiobookshelfService = AudiobookShelfConnectionService()
    audiobookshelfService.setup()
    self.audiobookshelfConnectionService = audiobookshelfService

    self.hardcoverService = coreServices.hardcoverService
    self.preferencesService = coreServices.preferencesService

    ThemeManager.shared.libraryService = libraryService

    super.init()

    setUpTheming()
  }

  func start() {
    if var currentTheme = libraryService.getLibraryCurrentTheme() {
      currentTheme.useDarkVariant = ThemeManager.shared.useDarkVariant
      ThemeManager.shared.currentTheme = currentTheme
    }

    bindObservers()

    accountService.loginIfUserExists(delegate: self)

    let vc = AppHostingViewController(
      rootView: MainView {
        self.showSecondOnboarding()
      } showImport: {
        self.showImport()
      }
      .environmentObject(singleFileDownloadService)
      .environmentObject(importManager)
      .environmentObject(playerManager)
      .environmentObject(listSyncRefreshService)
      .environment(\.libraryService, libraryService)
      .environment(\.accountService, accountService)
      .environment(\.syncService, syncService)
      .environment(\.jellyfinService, jellyfinConnectionService)
      .environment(\.audiobookshelfService, audiobookshelfConnectionService)
      .environment(\.hardcoverService, hardcoverService)
      .environment(\.playerState, playerState)
      .environment(\.playerLoaderService, playerLoaderService)
      .environment(\.playbackService, playbackService)
      .environment(\.preferencesService, preferencesService)
      .environment(\.syncQueueService, syncQueueService)
      .environment(\.uploadContinuation, AppServices.shared.uploadContinuation)
    )
    vc.modalPresentationStyle = .fullScreen
    vc.modalTransitionStyle = .crossDissolve
    
    // Set window interface style BEFORE presenting the view controller
    // This ensures SwiftUI views are initialized with the correct colorScheme
    if let window = navigationController.view.window ?? WindowHelper.activeWindow {
      if UserDefaults.standard.bool(forKey: Constants.UserDefaults.systemThemeVariantEnabled) {
        window.overrideUserInterfaceStyle = .unspecified
      } else {
        window.overrideUserInterfaceStyle = ThemeManager.shared.useDarkVariant ? .dark : .light
      }
    }
    
    navigationController.present(vc, animated: false)
    mainController = vc

    AppServices.shared.coreServices?.watchService.startSession()
  }

  func showSecondOnboarding() {
    guard let anonymousId = accountService.getAnonymousId() else { return }

    let coordinator = SecondOnboardingCoordinator(
      flow: .modalOnlyFlow(
        presentingController: mainController!,
        modalPresentationStyle: .fullScreen
      ),
      anonymousId: anonymousId,
      accountService: accountService,
      eventsService: EventsService()
    )
    coordinator.start()
  }

  func showImport() {
    guard
      importManager.hasPendingFiles(),
      importCoordinator == nil,
      let topVC = WindowHelper.activeWindow?.rootViewController?.getTopVisibleViewController()
    else { return }

    let coordinator = ImportCoordinator(
      flow: .modalFlow(presentingController: topVC),
      importManager: self.importManager
    )
    importCoordinator = coordinator
    coordinator.start()
  }

  func bindObservers() {
    playerManager.currentItemPublisher()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] item in
        self?.playerState.loadedBookRelativePath = item?.relativePath
      }
      .store(in: &disposeBag)
  }

  func loadPlayer(_ relativePath: String, intent: PlayIntent, showPlayer: Bool) {
    Task { @MainActor in
      let alertPresenter: AlertPresenter = self
      do {
        try await AppServices.shared.coreServices?.playerLoaderService.loadPlayer(
          relativePath,
          intent: intent
        )
        if showPlayer {
          self.showPlayer()
        }
      } catch BPPlayerError.fileMissing {
        alertPresenter.showAlert(
          "file_missing_title".localized,
          message:
            "\("file_missing_description".localized)\n\(relativePath)",
          completion: nil
        )
      } catch {
        alertPresenter.showAlert(
          "error_title".localized,
          message: error.localizedDescription,
          completion: nil
        )
      }
    }
  }

  func showPlayer() {
    playerState.showPlayer = true
  }
  
  func hasPlayerShown() -> Bool {
    return playerState.isShowingPlayer
  }

  func processFiles(urls: [URL]) {
    var filesToCopy = [URL]()

    for url in urls {
      if DataManager.isAppManagedSource(url) {
        importManager.process(url)
      } else {
        filesToCopy.append(url)
      }
    }

    copyIntoDocuments(filesToCopy)
  }

  /// Files handed over from outside the app go into Documents now, as picked and dropped ones do, and the
  /// Documents watcher queues the copy for import. The system's own copy sits in a temporary folder that
  /// may not last until the import is done (since iOS 17?), and a file another app opened in place
  /// (iCloud Drive, On My iPhone) can only be read while this URL's access is held. Off the main thread: a
  /// file in iCloud Drive that isn't downloaded yet downloads before the copy.
  private func copyIntoDocuments(_ urls: [URL]) {
    guard !urls.isEmpty else { return }

    let documentsFolder = DataManager.getDocumentsFolderURL()

    Task.detached(priority: .userInitiated) { [weak self] in
      for url in urls {
        do {
          try MainCoordinator.copyFile(url, into: documentsFolder)
        } catch {
          await self?.showAlert("error_title".localized, message: error.localizedDescription)
        }
      }
    }
  }

  /// Copies a file handed over from outside the app into `folder`, unless a file of that name is already
  /// there. Blocks until the copy is done.
  nonisolated static func copyFile(_ url: URL, into folder: URL) throws {
    let accessGranted = url.startAccessingSecurityScopedResource()
    defer {
      if accessGranted { url.stopAccessingSecurityScopedResource() }
    }

    let destinationURL = folder.appendingPathComponent(url.lastPathComponent)
    guard !FileManager.default.fileExists(atPath: destinationURL.path) else { return }

    // Copied into a folder of its own first and moved in whole. The Documents watcher reports a file once
    // its size stops changing, which a copy stalled on a slow source (a download, a network drive) would fake.
    let stagingFolder = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: stagingFolder) }

    try FileManager.default.createDirectory(at: stagingFolder, withIntermediateDirectories: true)
    let stagedURL = stagingFolder.appendingPathComponent(url.lastPathComponent)

    // A coordinated read has the file's provider (iCloud Drive, another app's storage) download it first and
    // waits for it. A plain read of a file that isn't downloaded yet times out on a slow download.
    var coordinationError: NSError?
    var copyError: Error?
    NSFileCoordinator().coordinate(readingItemAt: url, options: .withoutChanges, error: &coordinationError) { readURL in
      do {
        try FileManager.default.copyItem(at: readURL, to: stagedURL)
      } catch {
        copyError = error
      }
    }
    if let error = coordinationError ?? copyError { throw error }

    try FileManager.default.moveItem(at: stagedURL, to: destinationURL)
    destinationURL.disableFileProtection()
  }
}

extension MainCoordinator: PurchasesDelegate {
  nonisolated public func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
    Task { @MainActor in
      self.accountService.updateAccount(from: customerInfo)
    }
  }
}

extension MainCoordinator: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    guard
      !UserDefaults.standard.bool(forKey: Constants.UserDefaults.systemThemeVariantEnabled)
    else {
      WindowHelper.activeWindow?.overrideUserInterfaceStyle = .unspecified
      return
    }
    // This fixes native components like alerts having the proper color theme
    WindowHelper.activeWindow?.overrideUserInterfaceStyle =
      theme.useDarkVariant
      ? .dark
      : .light
  }
}

extension MainCoordinator: AlertPresenter {
  func showAlert(_ title: String? = nil, message: String? = nil, completion: (() -> Void)? = nil) {
    mainController?.showAlert(title, message: message, completion: completion)
  }

  func showAlert(_ content: BPAlertContent) {
    mainController?.showAlert(content)
  }

  func showLoader() {
    LoadingUtils.loadAndBlock(in: mainController!)
  }

  func stopLoader() {
    LoadingUtils.stopLoading(in: mainController!)
  }
}
