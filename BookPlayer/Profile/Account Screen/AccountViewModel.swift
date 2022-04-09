//
//  AccountViewModel.swift
//  BookPlayer
//
//  Created by gianni.carlo on 8/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation

class AccountViewModel: BaseViewModel<AccountCoordinator> {
  func showCompleteAccount() {
    self.coordinator.showCompleteAccount()
  }
}
