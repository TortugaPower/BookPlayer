//
//  ProfileViewModel.swift
//  BookPlayer
//
//  Created by gianni.carlo on 12/3/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation
import BookPlayerKit
import Combine

class ProfileViewModel: BaseViewModel<ProfileCoordinator> {
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

  func showAccount() {
    self.coordinator.showAccount()
  }
}
