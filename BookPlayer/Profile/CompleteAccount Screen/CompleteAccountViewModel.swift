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

  lazy var pricingViewModel = PricingViewModel(
    options: accountService.getHardcodedSubscriptionOptions()
  )

  /// Callback to handle actions on this screen
  var onTransition: Transition<Routes>?

  init(
    accountService: AccountServiceProtocol,
    account: Account
  ) {
    self.accountService = accountService
    self.account = account
  }

  func loadPricingOptions() {
    Task { @MainActor [weak self] in
      if let options = try? await self?.accountService.getSubscriptionOptions() {
        self?.pricingViewModel.options = options
        self?.pricingViewModel.selected = options.first
      }

      self?.pricingViewModel.isLoading = false
    }
  }

  func handleSubscription() {
    guard
      pricingViewModel.isLoading == false,
      let selectedOption = pricingViewModel.selected
    else { return }

    Task { @MainActor [weak self, accountService] in
      self?.coordinator.showLoader()

      do {
        let userCancelled = try await accountService.subscribe(option: selectedOption)

        self?.coordinator.stopLoader()
        if !userCancelled {
          self?.onTransition?(.success)
        }

      } catch {
        self?.coordinator.stopLoader()
        self?.coordinator.showError(error)
      }
    }
  }

  func handleRestorePurchases() {
    Task { @MainActor [weak self, accountService] in
      self?.coordinator.showLoader()

      do {
        let customerInfo = try await accountService.restorePurchases()

        if customerInfo.activeSubscriptions.isEmpty {
          throw AccountError.inactiveSubscription
        }

        self?.coordinator.stopLoader()
        self?.onTransition?(.success)
      } catch {
        self?.coordinator.stopLoader()
        self?.coordinator.showError(error)
      }
    }
  }

  func openLink(_ url: URL) {
    onTransition?(.link(url))
  }
}
