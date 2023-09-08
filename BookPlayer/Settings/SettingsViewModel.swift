//
//  SettingsViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 30/10/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
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
    case storageManagement
    case deletedFilesManagement
    case tipJar
    case credits
  }
  weak var coordinator: SettingsCoordinator!
  let accountService: AccountServiceProtocol

  var onTransition: BPTransition<Routes>?

  @Published var account: Account?

  private var disposeBag = Set<AnyCancellable>()

  init(accountService: AccountServiceProtocol) {
    self.accountService = accountService
    self.reloadAccount()
    self.bindObservers()
  }

  func bindObservers() {
    NotificationCenter.default.publisher(for: .accountUpdate, object: nil)
      .sink(receiveValue: { [weak self] _ in
        self?.reloadAccount()
      })
      .store(in: &disposeBag)
  }

  func reloadAccount() {
    self.account = self.accountService.getAccount()
  }

  func hasMadeDonation() -> Bool {
    return account?.hasSubscription == true
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

  func showCredits() {
    onTransition?(.credits)
  }
}
