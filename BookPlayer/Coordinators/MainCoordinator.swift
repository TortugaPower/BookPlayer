//
//  MainCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import RevenueCat
import Themeable
import UIKit

class MainCoordinator: NSObject {
  var tabBarController: AppTabBarController?

  let playerManager: PlayerManagerProtocol
  let libraryService: LibraryServiceProtocol
  let playbackService: PlaybackServiceProtocol
  let accountService: AccountServiceProtocol
  var syncService: SyncServiceProtocol
  let watchConnectivityService: PhoneWatchConnectivityService

  let navigationController: UINavigationController
  var libraryCoordinator: LibraryListCoordinator?
  private var disposeBag = Set<AnyCancellable>()

  init(
    navigationController: UINavigationController,
    coreServices: CoreServices
  ) {
    self.navigationController = navigationController
    self.libraryService = coreServices.libraryService
    self.accountService = coreServices.accountService
    self.syncService = coreServices.syncService
    self.playbackService = coreServices.playbackService
    self.playerManager = coreServices.playerManager
    self.watchConnectivityService = coreServices.watchService

    ThemeManager.shared.libraryService = libraryService

    super.init()

    setUpTheming()
  }

  func start() {
    let viewModel = MiniPlayerViewModel(playerManager: playerManager)

    viewModel.onTransition = { route in
      switch route {
      case .showPlayer:
        self.showPlayer()
      case .loadItem(let relativePath, let autoplay, let showPlayer):
        self.loadPlayer(relativePath, autoplay: autoplay, showPlayer: showPlayer)
      }
    }

    let tabBarController = AppTabBarController(miniPlayerViewModel: viewModel)
    self.tabBarController = tabBarController
    tabBarController.modalPresentationStyle = .fullScreen
    tabBarController.modalTransitionStyle = .crossDissolve

    if var currentTheme = libraryService.getLibraryCurrentTheme() {
      currentTheme.useDarkVariant = ThemeManager.shared.useDarkVariant
      ThemeManager.shared.currentTheme = currentTheme
    }

    bindObservers()

    accountService.loginIfUserExists(delegate: self)

    startLibraryCoordinator(with: tabBarController)

    startProfileCoordinator(with: tabBarController)

    startSettingsCoordinator(with: tabBarController)

    navigationController.present(tabBarController, animated: false)
  }

  func startLibraryCoordinator(with tabBarController: UITabBarController) {
    let libraryCoordinator = LibraryListCoordinator(
      flow: .pushFlow(navigationController: AppNavigationController.instantiate(from: .Main)),
      playerManager: self.playerManager,
      libraryService: self.libraryService,
      playbackService: self.playbackService,
      syncService: syncService,
      importManager: ImportManager(libraryService: self.libraryService),
      listRefreshService: ListSyncRefreshService(
        playerManager: playerManager,
        syncService: syncService
      ), 
      accountService: self.accountService
    )
    playerManager.syncProgressDelegate = libraryCoordinator
    self.libraryCoordinator = libraryCoordinator
    libraryCoordinator.tabBarController = tabBarController
    libraryCoordinator.start()
  }

  func startProfileCoordinator(with tabBarController: UITabBarController) {
    let profileCoordinator = ProfileCoordinator(
      flow: .pushFlow(navigationController: AppNavigationController.instantiate(from: .Main)),
      libraryService: libraryService,
      playerManager: playerManager,
      accountService: accountService,
      syncService: syncService
    )
    profileCoordinator.tabBarController = tabBarController
    profileCoordinator.start()
  }

  func startSettingsCoordinator(with tabBarController: UITabBarController) {
    let settingsCoordinator = SettingsCoordinator(
      flow: .pushFlow(navigationController: AppNavigationController.instantiate(from: .Settings)),
      libraryService: self.libraryService, 
      syncService: self.syncService,
      accountService: self.accountService
    )
    settingsCoordinator.tabBarController = tabBarController
    settingsCoordinator.start()
  }

  func bindObservers() {
    NotificationCenter.default.publisher(for: .accountUpdate, object: nil)
      .sink(receiveValue: { [weak self] _ in
        guard
          let self = self,
          self.accountService.hasAccount()
        else { return }

        if self.accountService.hasSyncEnabled() {
          if !self.syncService.isActive {
            self.syncService.isActive = true
            self.getLibraryCoordinator()?.syncList()
          }
        } else {
          if self.syncService.isActive {
            self.syncService.isActive = false
            self.syncService.cancelAllJobs()
          }
        }

      })
      .store(in: &disposeBag)
  }

  func loadPlayer(_ relativePath: String, autoplay: Bool, showPlayer: Bool) {
    AppDelegate.shared?.loadPlayer(
      relativePath,
      autoplay: autoplay,
      showPlayer: { [weak self] in
        if showPlayer {
          self?.showPlayer()
        }
      },
      alertPresenter: (getLibraryCoordinator() ?? self)
    )
  }

  func showPlayer() {
    let playerCoordinator = PlayerCoordinator(
      flow: .modalOnlyFlow(presentingController: tabBarController!, modalPresentationStyle: .overFullScreen),
      playerManager: self.playerManager,
      libraryService: self.libraryService,
      syncService: self.syncService
    )
    playerCoordinator.start()
  }

  func showMiniPlayer(_ flag: Bool) {
    // Only animate if it toggles the state
    guard
      let tabBarController,
      flag != tabBarController.isMiniPlayerVisible
    else { return }

    guard flag else {
      tabBarController.animateView(tabBarController.miniPlayer, show: flag)
      return
    }

    if self.playerManager.hasLoadedBook() {
      tabBarController.animateView(tabBarController.miniPlayer, show: flag)
    }
  }

  func hasPlayerShown() -> Bool {
    return libraryCoordinator?.flow.navigationController.visibleViewController is PlayerViewController
  }

  func getLibraryCoordinator() -> LibraryListCoordinator? {
    return libraryCoordinator
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
    AppDelegate.shared?.activeSceneDelegate?.window?.overrideUserInterfaceStyle = theme.useDarkVariant
    ? .dark
    : .light
  }
}

extension MainCoordinator: AlertPresenter {
  func showAlert(_ title: String? = nil, message: String? = nil, completion: (() -> Void)? = nil) {
    navigationController.showAlert(title, message: message, completion: completion)
  }

  func showLoader() {
    LoadingUtils.loadAndBlock(in: navigationController)
  }

  func stopLoader() {
    LoadingUtils.stopLoading(in: navigationController)
  }
}
