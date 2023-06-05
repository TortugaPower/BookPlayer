//
//  IconsViewModel.swift
//  BookPlayer
//
//  Created by gianni.carlo on 11/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine

final class IconsViewModel {
  weak var coordinator: SettingsCoordinator!
  let accountService: AccountServiceProtocol

  @Published var account: Account?

  var hasSubscription: Bool {
    return account?.hasSubscription == true
  }

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
    return (self.account?.donationMade ?? false) || account?.hasSubscription == true
  }

  func showPro() {
    self.coordinator.showPro()
  }
}
