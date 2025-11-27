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
  let hardcoverService: HardcoverService

  let playerState = PlayerState()

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
      playerLoaderService: coreServices.playerLoaderService
    )
    self.singleFileDownloadService = SingleFileDownloadService(networkClient: NetworkClient())
    self.watchConnectivityService = coreServices.watchService
    let jellyfinService = JellyfinConnectionService()
    jellyfinService.setup()
    self.jellyfinConnectionService = jellyfinService

    let audiobookshelfService = AudiobookShelfConnectionService()
    audiobookshelfService.setup()
    self.audiobookshelfConnectionService = audiobookshelfService

    self.hardcoverService = coreServices.hardcoverService

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
      } showPlayer: {
        self.showPlayer()
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
    )
    vc.modalPresentationStyle = .fullScreen
    vc.modalTransitionStyle = .crossDissolve
    
    // Set window interface style BEFORE presenting the view controller
    // This ensures SwiftUI views are initialized with the correct colorScheme
    if let window = navigationController.view.window ?? AppDelegate.shared?.activeSceneDelegate?.window {
      if UserDefaults.standard.bool(forKey: Constants.UserDefaults.systemThemeVariantEnabled) {
        window.overrideUserInterfaceStyle = .unspecified
      } else {
        window.overrideUserInterfaceStyle = ThemeManager.shared.useDarkVariant ? .dark : .light
      }
    }
    
    navigationController.present(vc, animated: false)
    mainController = vc

    AppDelegate.shared?.coreServices?.watchService.startSession()
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
      let topVC = AppDelegate.shared?.activeSceneDelegate?.startingNavigationController.getTopVisibleViewController()
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

  func loadPlayer(_ relativePath: String, autoplay: Bool, showPlayer: Bool) {
    Task { @MainActor in
      let alertPresenter: AlertPresenter = self
      do {
        try await AppDelegate.shared?.coreServices?.playerLoaderService.loadPlayer(
          relativePath,
          autoplay: autoplay
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
    let playerCoordinator = PlayerCoordinator(
      flow: .modalOnlyFlow(presentingController: mainController!, modalPresentationStyle: .overFullScreen),
      playerManager: self.playerManager,
      libraryService: self.libraryService,
      syncService: self.syncService
    )
    playerCoordinator.start()
  }

  func hasPlayerShown() -> Bool {
    return mainController?.presentedViewController is PlayerViewController
  }

  func processFiles(urls: [URL]) {
    let temporaryDirectoryPath = FileManager.default.temporaryDirectory.absoluteString
    let documentsFolder = DataManager.getDocumentsFolderURL()

    for url in urls {
      /// At some point (iOS 17?), the OS stopped sending the picked files to the Documents/Inbox folder, instead
      /// it's now sent to a temp folder that can't be relied on to keep the file existing until the import is finished
      if url.absoluteString.contains(temporaryDirectoryPath) {
        let destinationURL = documentsFolder.appendingPathComponent(url.lastPathComponent)
        if !FileManager.default.fileExists(atPath: destinationURL.path) {
          try! FileManager.default.copyItem(at: url, to: destinationURL)
        }
      } else {
        importManager.process(url)
      }
    }
  }
}

extension MainCoordinator: PurchasesDelegate {
  public func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
    self.accountService.updateAccount(from: customerInfo)
  }
}

extension MainCoordinator: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    guard
      !UserDefaults.standard.bool(forKey: Constants.UserDefaults.systemThemeVariantEnabled)
    else {
      AppDelegate.shared?.activeSceneDelegate?.window?.overrideUserInterfaceStyle = .unspecified
      return
    }
    // This fixes native components like alerts having the proper color theme
    AppDelegate.shared?.activeSceneDelegate?.window?.overrideUserInterfaceStyle =
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
