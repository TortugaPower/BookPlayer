//
//  TipJarViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 3/2/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation
import RevenueCat

public final class TipJarViewModel: ObservableObject {
  enum Routes {
    case showLoader(Bool)
    case showAlert(BPAlertContent)
    case success(message: String)
    case dismiss
  }

  @Published var isLoading: Bool = true
  @Published var localizedPrices: [String: String] = [
    TipOption.kind.rawValue: TipOption.kind.price,
    TipOption.excellent.rawValue: TipOption.excellent.price,
    TipOption.incredible.rawValue: TipOption.incredible.price
  ]
  let disclaimer: String?
  let accountService: AccountServiceProtocol
  /// Callback to handle actions on this screen
  var onTransition: BPTransition<Routes>?

  init(
    disclaimer: String?,
    accountService: AccountServiceProtocol
  ) {
    self.disclaimer = disclaimer
    self.accountService = accountService
    self.loadPrices()
  }

  @MainActor
  func donate(_ tip: TipOption) async {
    onTransition?(.showLoader(true))
    do {
      let product = await Purchases.shared.products([tip.rawValue]).first!
      let result = try await Purchases.shared.purchase(product: product)
      onTransition?(.showLoader(false))
      if !result.userCancelled {
        accountService.updateAccount(
          id: nil,
          email: nil,
          donationMade: true,
          hasSubscription: nil
        )
        onTransition?(.success(message: "thanks_amazing_title".localized))
      }
    } catch {
      onTransition?(.showLoader(false))
      onTransition?(
        .showAlert(
          BPAlertContent.errorAlert(message: error.localizedDescription)
        )
      )
    }
  }

  @MainActor
  func restorePurchases() async {
    onTransition?(.showLoader(true))
    do {
      let customerInfo = try await Purchases.shared.restorePurchases()
      onTransition?(.showLoader(false))
      if customerInfo.nonSubscriptions.isEmpty {
        onTransition?(
          .showAlert(
            BPAlertContent.errorAlert(message: "tip_missing_title".localized)
          )
        )
      } else {
        accountService.updateAccount(
          id: nil,
          email: nil,
          donationMade: true,
          hasSubscription: nil
        )
        onTransition?(.success(message: "purchases_restored_title".localized))
      }
    } catch {
      onTransition?(.showLoader(false))
      onTransition?(
        .showAlert(
          BPAlertContent.errorAlert(message: error.localizedDescription)
        )
      )
    }
  }

  @MainActor
  func dismiss() {
    onTransition?(.dismiss)
  }

  func loadPrices() {
    Task { @MainActor in
      let products = await Purchases.shared.products([
        TipOption.kind.rawValue,
        TipOption.excellent.rawValue,
        TipOption.incredible.rawValue
      ])

      products.forEach {
        self.localizedPrices[$0.productIdentifier] = $0.localizedPriceString
      }

      self.isLoading = false
    }
  }
}
