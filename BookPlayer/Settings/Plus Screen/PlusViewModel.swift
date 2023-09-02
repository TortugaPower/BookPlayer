//
//  PlusViewModel.swift
//  BookPlayer
//
//  Created by gianni.carlo on 11/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine

final class PlusViewModel {
  weak var coordinator: SettingsCoordinator!
  let accountService: AccountServiceProtocol

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
    // Force true to only show the tip jar screen
    return true
  }

  func handleRestoreDonation() {
    self.accountService.updateAccount(
      id: nil,
      email: nil,
      donationMade: true,
      hasSubscription: nil
    )
  }

  func handleNewDonation() {
    /// Register that there was a donation
    BPSKANManager.updateConversionValue(.donation)
    self.accountService.updateAccount(
      id: nil,
      email: nil,
      donationMade: true,
      hasSubscription: nil
    )
  }
}
