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

class SettingsViewModel: BaseViewModel<SettingsCoordinator> {
  let accountService: AccountServiceProtocol

  @Published var account: Account?

  private var disposeBag = Set<AnyCancellable>()

  init(accountService: AccountServiceProtocol) {
    self.accountService = accountService

    super.init()

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
    UserDefaults.standard.set(flag, forKey: Constants.UserDefaults.iCloudBackupsEnabled.rawValue)

    // Modify the processed folder to be considered for backups
    var resourceValues = URLResourceValues()
    resourceValues.isExcludedFromBackup = !flag
    var processedFolderURL = DataManager.getProcessedFolderURL()

    try? processedFolderURL.setResourceValues(resourceValues)
  }

  func showPro() {
    self.coordinator.showPro()
  }

  func showTipJar() {
    self.coordinator.showTipJar()
  }

  func showStorageManagement() {
    self.coordinator.showStorageManagement()
  }

  func showThemes() {
    self.coordinator.showThemes()
  }

  func showIcons() {
    self.coordinator.showIcons()
  }

  func showPlayerControls() {
    self.coordinator.showPlayerControls()
  }

  func showCredits() {
    self.coordinator.showCredits()
  }
}
