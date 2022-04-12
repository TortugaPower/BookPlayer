//
//  AccountViewModel.swift
//  BookPlayer
//
//  Created by gianni.carlo on 8/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation
import BookPlayerKit

class AccountViewModel: BaseViewModel<AccountCoordinator> {
  let accountService: AccountServiceProtocol

  init(accountService: AccountServiceProtocol) {
    self.accountService = accountService
  }

  func showCompleteAccount() {
    self.coordinator.showCompleteAccount()
  }

  func handleLogout() {
    self.accountService.logout()
    self.dismiss()
  }

  func handleDelete() {
    // TODO: handle delete account
  }
}
