//
//  SettingsViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 30/10/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation

class SettingsViewModel: ViewModelProtocol {
  /// Available routes
  enum Routes {
    case pro
    case themes
    case icons
    case playerControls
    case autoplay
    case autolock
    case storageManagement
    case deletedFilesManagement
    case tipJar
    case jellyfinConnectionManagement
    case hardcoverManagement
  }

  enum Events {
    case showLoader(flag: Bool)
    case showAlert(content: BPAlertContent)
  }

  weak var coordinator: SettingsCoordinator!
  let accountService: AccountServiceProtocol
  let libraryService: LibraryServiceProtocol
  let syncService: SyncServiceProtocol
  let jellyfinConnectionService: JellyfinConnectionService

  var onTransition: BPTransition<Routes>?

  @Published var account: Account?
  @Published var hasJellyfinConnection: Bool = false

  private var disposeBag = Set<AnyCancellable>()
  var eventsPublisher = InterfaceUpdater<SettingsViewModel.Events>()

  init(
    accountService: AccountServiceProtocol,
    libraryService: LibraryServiceProtocol,
    syncService: SyncServiceProtocol,
    jellyfinConnectionService: JellyfinConnectionService
  ) {
    self.accountService = accountService
    self.libraryService = libraryService
    self.syncService = syncService
    self.jellyfinConnectionService = jellyfinConnectionService
    
    self.reloadAccount()
    
    self.bindObservers()
  }

  func bindObservers() {
    NotificationCenter.default.publisher(for: .accountUpdate, object: nil)
      .sink(receiveValue: { [weak self] _ in
        self?.reloadAccount()
      })
      .store(in: &disposeBag)
    
    jellyfinConnectionService.$connection
      .sink { [weak self] connection in
        self?.hasJellyfinConnection = connection != nil
      }
      .store(in: &disposeBag)
  }

  func observeEvents() -> AnyPublisher<SettingsViewModel.Events, Never> {
    eventsPublisher.eraseToAnyPublisher()
  }

  private func sendEvent(_ event: SettingsViewModel.Events) {
    eventsPublisher.send(event)
  }

  func reloadAccount() {
    self.account = self.accountService.getAccount()
  }

  func hasActiveSubscription() -> Bool {
    return accountService.hasSyncEnabled()
  }

  func hasMadeDonation() -> Bool {
    return accountService.hasPlusAccess()
  }

  func getAnonymousId() -> String {
    return accountService.getAnonymousId() ?? ""
  }

  /// Handle registering the value in `UserDefaults`
  func toggleCellularDataUsage(_ flag: Bool) {
    UserDefaults.standard.set(flag, forKey: Constants.UserDefaults.allowCellularData)
  }

  func toggleFileBackupsPreference(_ flag: Bool) {
    UserDefaults.standard.set(flag, forKey: Constants.UserDefaults.iCloudBackupsEnabled)

    // Modify the processed folder to be considered for backups
    var resourceValues = URLResourceValues()
    resourceValues.isExcludedFromBackup = !flag
    var processedFolderURL = DataManager.getProcessedFolderURL()

    try? processedFolderURL.setResourceValues(resourceValues)
  }

  /// Handle registering the value in `UserDefaults`
  func toggleCrashReportsAccess(_ flag: Bool) {
    UserDefaults.standard.set(flag, forKey: Constants.UserDefaults.crashReportsDisabled)
  }

  /// Handle registering the value in `UserDefaults`
  func toggleSKANPreference(_ flag: Bool) {
    UserDefaults.standard.set(flag, forKey: Constants.UserDefaults.skanAttributionDisabled)
  }

  /// Handle registering the value in `UserDefaults`
  func toggleOrientationLockPreference(_ flag: Bool) {
    if flag {
      UserDefaults.standard.set(
        UIDevice.current.orientation.rawValue,
        forKey: Constants.UserDefaults.orientationLock
      )
    } else {
      UserDefaults.standard.removeObject(forKey: Constants.UserDefaults.orientationLock)
    }
  }

  func showPro() {
    onTransition?(.pro)
  }

  func showTipJar() {
    onTransition?(.tipJar)
  }

  func showStorageManagement() {
    onTransition?(.storageManagement)
  }

  func showCloudDeletedFiles() {
    onTransition?(.deletedFilesManagement)
  }

  func showThemes() {
    onTransition?(.themes)
  }

  func showIcons() {
    onTransition?(.icons)
  }

  func showPlayerControls() {
    onTransition?(.playerControls)
  }

  func showAutoplay() {
    onTransition?(.autoplay)
  }

  func showAutolock() {
    onTransition?(.autolock)
  }
  
  func showJellyfinConnectionManagement() {
    onTransition?(.jellyfinConnectionManagement)
  }

  func showHardcoverManagement() {
    onTransition?(.hardcoverManagement)
  }
}
