//
//  PurchasesManager.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation
import RevenueCat

enum PurchaseError: LocalizedError {
  case testFlightPurchasesDisabled
  
  var errorDescription: String? {
    switch self {
    case .testFlightPurchasesDisabled:
      return "In-app purchases are disabled in TestFlight builds. Please download the app from the App Store for donations or new subscriptions."
    }
  }
}

struct PurchasesManager {
  static func restoreTips(
    loadingState: LoadingOverlayState,
    onSuccess: @escaping () -> Void
  ) {
    guard AppEnvironment.isPurchaseEnabled else {
      loadingState.error = PurchaseError.testFlightPurchasesDisabled
      return
    }
    
    loadingState.show = true

    Task { @MainActor in
      do {
        let customerInfo = try await Purchases.shared.restorePurchases()

        if customerInfo.nonSubscriptions.isEmpty {
          loadingState.show = false
          throw "tip_missing_title".localized
        }

        loadingState.show = false
        onSuccess()
      } catch {
        loadingState.show = false
        loadingState.error = error
      }
    }
  }

  static func restoreSubscriptions(
    loadingState: LoadingOverlayState,
    onSuccess: @escaping () -> Void
  ) {
    guard AppEnvironment.isPurchaseEnabled else {
      loadingState.error = PurchaseError.testFlightPurchasesDisabled
      return
    }
    
    loadingState.show = true

    Task { @MainActor in
      do {
        let customerInfo = try await Purchases.shared.restorePurchases()

        if customerInfo.activeSubscriptions.isEmpty {
          throw AccountError.inactiveSubscription
        }

        loadingState.show = false
        onSuccess()
      } catch {
        loadingState.show = false
        loadingState.error = error
      }
    }
  }
}
