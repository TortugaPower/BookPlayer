//
//  AccountViewModel.swift
//  BookPlayer
//
//  Created by gianni.carlo on 8/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation
import BookPlayerKit
import Combine
import RevenueCat

class AccountViewModel: BaseViewModel<AccountCoordinator> {
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

  func showCompleteAccount() {
    self.coordinator.showCompleteAccount()
  }

  func hasSubscription() -> Bool {
    return self.account?.hasSubscription ?? false
  }

  func showManageSubscription() {
    guard !ProcessInfo.processInfo.isiOSAppOnMac else {
      self.coordinator.showError(AccountError.managementUnavailable)
      return
    }

    Purchases.shared.showManageSubscriptions() { _ in }
  }

  func handleLogout() {
    self.accountService.logout()
    self.dismiss()
  }

  func handleDelete() {
    // TODO: handle delete account
  }
}
