//
//  CompleteAccountViewModel.swift
//  BookPlayer
//
//  Created by gianni.carlo on 8/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Foundation

protocol CompleteAccountViewModelProtocol: ObservableObject {
  var pricingOptions: [PricingModel] { get set }
  var selectedPricingOption: PricingModel? { get set }
  var isLoadingPricingOptions: Bool { get set }
  var networkError: Error? { get set }

  func handleSubscription()
  func handleRestorePurchases()
  func dismiss()
}

class CompleteAccountViewModel: CompleteAccountViewModelProtocol {
  enum Routes {
    case link(_ url: URL)
    case showLoader(Bool)
    case success
    case dismiss
  }

  @Published var pricingOptions: [PricingModel]
  @Published var selectedPricingOption: PricingModel?
  @Published var isLoadingPricingOptions: Bool = true

  @Published var networkError: Error?

  let accountService: AccountServiceProtocol
  let account: Account
  let containerImageWidth: CGFloat = 60
  let imageWidth: CGFloat = 35

  /// Callback to handle actions on this screen
  var onTransition: BPTransition<Routes>?

  init(
    accountService: AccountServiceProtocol,
    account: Account
  ) {
    self.accountService = accountService
    self.account = account
    let options = accountService.getHardcodedSubscriptionOptions()
    self.pricingOptions = options
    self.selectedPricingOption = options.first
    self.loadPricingOptions()
  }

  func loadPricingOptions() {
    Task { @MainActor [weak self] in
      if let options = try? await self?.accountService.getSubscriptionOptions() {
        self?.pricingOptions = options
        self?.selectedPricingOption = options.first
      }

      self?.isLoadingPricingOptions = false
    }
  }

  func handleSubscription() {
    guard
      isLoadingPricingOptions == false,
      let selectedOption = selectedPricingOption
    else { return }

    Task { @MainActor [weak self] in
      guard let self = self else { return }

      self.onTransition?(.showLoader(true))

      do {
        let userCancelled = try await self.accountService.subscribe(option: selectedOption)
        self.onTransition?(.showLoader(false))
        if !userCancelled {
          self.onTransition?(.success)
        }
      } catch {
        self.onTransition?(.showLoader(false))
        self.networkError = error
      }
    }
  }

  func handleRestorePurchases() {
    Task { @MainActor [weak self] in
      guard let self = self else { return }
      self.onTransition?(.showLoader(true))

      do {
        let customerInfo = try await self.accountService.restorePurchases()

        if customerInfo.activeSubscriptions.isEmpty {
          throw AccountError.inactiveSubscription
        }

        self.onTransition?(.showLoader(false))
        self.onTransition?(.success)
      } catch {
        self.onTransition?(.showLoader(false))
        self.networkError = error
      }
    }
  }

  func openLink(_ url: URL) {
    onTransition?(.link(url))
  }

  func dismiss() {
    onTransition?(.dismiss)
  }
}
