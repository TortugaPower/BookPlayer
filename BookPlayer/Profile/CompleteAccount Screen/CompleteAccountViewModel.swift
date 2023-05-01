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
  enum Routes {
    case link(_ url: URL)
    case success
  }

  let accountService: AccountServiceProtocol
  let account: Account
  let containerImageWidth: CGFloat = 60
  let imageWidth: CGFloat = 35

  /// Callback to handle actions on this screen
  var onTransition: Transition<Routes>?

  init(
    accountService: AccountServiceProtocol,
    account: Account
  ) {
    self.accountService = accountService
    self.account = account
  }

  func handleSubscription() {
    Task { [weak self, accountService] in
      await MainActor.run { [weak self] in
        self?.coordinator.showLoader()
      }

      do {
        let userCancelled = try await accountService.subscribe()

        await MainActor.run { [weak self, userCancelled] in
          self?.coordinator.stopLoader()
          if !userCancelled {
            self?.onTransition?(.success)
          }
        }

      } catch {
        await MainActor.run { [weak self, error] in
          self?.coordinator.stopLoader()
          self?.coordinator.showError(error)
        }
      }
    }
  }

  func handleRestorePurchases() {
    Task { [weak self, accountService] in
      await MainActor.run { [weak self] in
        self?.coordinator.showLoader()
      }

      do {
        let customerInfo = try await accountService.restorePurchases()

        if customerInfo.activeSubscriptions.isEmpty {
          throw AccountError.inactiveSubscription
        }

        await MainActor.run { [weak self] in
          self?.coordinator.stopLoader()
          self?.onTransition?(.success)
        }
      } catch {
        await MainActor.run { [weak self, error] in
          self?.coordinator.stopLoader()
          self?.coordinator.showError(error)
        }
      }
    }
  }

  func openLink(_ url: URL) {
    onTransition?(.link(url))
  }
}
