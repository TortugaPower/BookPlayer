//
//  CompleteAccountViewModel.swift
//  BookPlayer
//
//  Created by gianni.carlo on 8/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Foundation

class CompleteAccountViewModel: BaseViewModel<CompleteAccountCoordinator> {
  let accountService: AccountServiceProtocol
  let account: Account

  init(
    accountService: AccountServiceProtocol,
    account: Account
  ) {
    self.accountService = accountService
    self.account = account
  }

  func handleSubscription() {
    // TODO: Handle in-app purchase
    self.dismiss()
  }
}
