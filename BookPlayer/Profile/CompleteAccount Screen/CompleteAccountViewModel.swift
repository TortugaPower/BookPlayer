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
    Task { [weak self, accountService] in
      do {
        let userCancelled = try await accountService.subscribe()

        guard !userCancelled else { return }

        await MainActor.run { [weak self] in
          self?.coordinator.showCongrats()
        }

      } catch {
        await MainActor.run { [weak self, error] in
          self?.coordinator.showError(error)
        }
      }
    }
  }

  func handleRestorePurchases() {
    Task { [weak self, accountService] in
      do {
        let customerInfo = try await accountService.restorePurchases()

        if customerInfo.activeSubscriptions.isEmpty {
          throw AccountError.inactiveSubscription
        }

        await MainActor.run { [weak self] in
          self?.coordinator.showCongrats()
        }
      } catch {
        await MainActor.run { [weak self, error] in
          self?.coordinator.showError(error)
        }
      }
    }
  }
}
