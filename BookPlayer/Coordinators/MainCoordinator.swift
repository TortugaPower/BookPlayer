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

class MainCoordinator: Coordinator {
  var tabBarController: AppTabBarController?

  let playerManager: PlayerManagerProtocol
  let libraryService: LibraryServiceProtocol
  let playbackService: PlaybackServiceProtocol
  let accountService: AccountServiceProtocol
  var syncService: SyncServiceProtocol
  let watchConnectivityService: PhoneWatchConnectivityService
  let socketService: SocketServiceProtocol

  private var disposeBag = Set<AnyCancellable>()

  init(
    navigationController: UINavigationController,
    coreServices: CoreServices
  ) {
    self.libraryService = coreServices.libraryService
    self.accountService = coreServices.accountService
    self.syncService = coreServices.syncService
    self.playbackService = coreServices.playbackService
    self.playerManager = coreServices.playerManager
    self.watchConnectivityService = coreServices.watchService
    self.socketService = coreServices.socketService

    ThemeManager.shared.libraryService = libraryService

    super.init(navigationController: navigationController, flowType: .modal)

    accountService.setDelegate(self)
    setUpTheming()
  }

  override func start() {
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
    presentingViewController = tabBarController

    if var currentTheme = libraryService.getLibraryCurrentTheme() {
      currentTheme.useDarkVariant = ThemeManager.shared.useDarkVariant
      ThemeManager.shared.currentTheme = currentTheme
    }

    bindObservers()

    accountService.loginIfUserExists()

    startLibraryCoordinator(with: tabBarController)

    startProfileCoordinator(with: tabBarController)

    startSettingsCoordinator(with: tabBarController)

    navigationController.present(tabBarController, animated: false)
  }

  func startLibraryCoordinator(with tabBarController: UITabBarController) {
    let libraryCoordinator = LibraryListCoordinator(
      navigationController: AppNavigationController.instantiate(from: .Main),
      playerManager: self.playerManager,
      importManager: ImportManager(libraryService: self.libraryService),
      libraryService: self.libraryService,
      playbackService: self.playbackService,
      syncService: syncService
    )
    libraryCoordinator.tabBarController = tabBarController
    libraryCoordinator.parentCoordinator = self
    self.childCoordinators.append(libraryCoordinator)
    libraryCoordinator.start()
  }

  func startProfileCoordinator(with tabBarController: UITabBarController) {
    let profileCoordinator = ProfileCoordinator(
      libraryService: libraryService,
      playerManager: playerManager,
      accountService: accountService,
      syncService: syncService,
      navigationController: AppNavigationController.instantiate(from: .Main)
    )
    profileCoordinator.tabBarController = tabBarController
    profileCoordinator.parentCoordinator = self
    self.childCoordinators.append(profileCoordinator)
    profileCoordinator.start()
  }

  func startSettingsCoordinator(with tabBarController: UITabBarController) {
    let settingsCoordinator = SettingsCoordinator(
      libraryService: self.libraryService,
      accountService: self.accountService,
      navigationController: AppNavigationController.instantiate(from: .Settings)
    )
    settingsCoordinator.tabBarController = tabBarController
    settingsCoordinator.parentCoordinator = self
    self.childCoordinators.append(settingsCoordinator)
    settingsCoordinator.start()
  }

  func bindObservers() {
    NotificationCenter.default.publisher(for: .accountUpdate, object: nil)
      .sink(receiveValue: { [weak self] _ in
        guard
          let self = self,
          let account = self.accountService.getAccount()
        else { return }

        if account.hasSubscription {
          self.socketService.connectSocket()

          let libraryCoordinator = self.getLibraryCoordinator()

          if !self.syncService.isActive {
            self.syncService.isActive = true
            libraryCoordinator?.syncLibrary()
          } else if !self.playerManager.hasLoadedBook() {
            libraryCoordinator?.loadLastBookIfNeeded()
          }
        } else {
          self.socketService.disconnectSocket()
          self.syncService.isActive = false
        }

      })
      .store(in: &disposeBag)

    NotificationCenter.default.publisher(for: .logout, object: nil)
      .sink(receiveValue: { [weak self] _ in
        self?.socketService.disconnectSocket()
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
      playerManager: self.playerManager,
      libraryService: self.libraryService,
      syncService: self.syncService,
      presentingViewController: self.presentingViewController
    )
    playerCoordinator.parentCoordinator = self
    self.childCoordinators.append(playerCoordinator)
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
    return self.childCoordinators.contains(where: { $0 is PlayerCoordinator })
  }

  func getLibraryCoordinator() -> LibraryListCoordinator? {
    return self.childCoordinators.first as? LibraryListCoordinator
  }

  func getTopController() -> UIViewController? {
    return getPresentingController(coordinator: self)
  }

  func getPresentingController(coordinator: Coordinator) -> UIViewController? {
    guard let lastCoordinator = coordinator.childCoordinators.last else {
      return coordinator.presentingViewController?.getTopViewController()
      ?? coordinator.navigationController
    }

    return getPresentingController(coordinator: lastCoordinator)
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
      !UserDefaults.standard.bool(forKey: Constants.UserDefaults.systemThemeVariantEnabled.rawValue)
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
