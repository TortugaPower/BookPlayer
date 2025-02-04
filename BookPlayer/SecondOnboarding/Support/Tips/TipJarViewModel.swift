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

@MainActor
public final class TipJarViewModel: ObservableObject {
  enum Routes {
    case showLoader(Bool)
    case showAlert(BPAlertContent)
    case success(message: String)
    case dismiss
  }

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
  }

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

  func dismiss() {
    onTransition?(.dismiss)
  }
}
