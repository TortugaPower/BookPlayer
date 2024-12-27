//
//  BPSKANManager.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 30/8/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation
import StoreKit

/// Manager that handles Apple's SKAdNetwork attribution while observing the user's preference
class BPSKANManager: BPLogger {
  enum BPConversionValue: String {
    /// Registers app install
    case install
    /// Registers if an import was completed
    case `import`
    /// Registers if an account was created
    case account
    /// Registers donation event
    case donation
    /// Registers subscription event
    case subscription

    /// Value received when there are many installs
    var fineValue: Int {
      switch self {
      case .install:
        return 0
      case .import:
        return 10
      case .account:
        return 20
      case .donation:
        return 30
      case .subscription:
        return 40
      }
    }

    /// Value received if there are low installs
    @available(iOS 16.1, *)
    var coarseValue: SKAdNetwork.CoarseConversionValue {
      switch self {
      case .install, .import, .account:
        return .low
      case .donation:
        return .medium
      case .subscription:
        return .high
      }
    }
  }

  /// Register event for Apple's SKAdNetwork
  /// - Parameter conversionValue: Event defined by ``BPConversionValue``
  /// - Note: This won't do anything if the user has disabled SKAN attribution in the privacy settings
  static func updateConversionValue(_ conversionValue: BPConversionValue) {
    /// Only continue if the user hasn't disabled attribution
    guard
      UserDefaults.standard.bool(forKey: Constants.UserDefaults.skanAttributionDisabled) == false
    else {
      Self.logger.trace("Attribution is disabled")
      return
    }

    Self.logger.trace("Updating conversion value: \(conversionValue.rawValue)")

    if #available(iOS 16.1, *) {
      SKAdNetwork.updatePostbackConversionValue(
        conversionValue.fineValue,
        coarseValue: conversionValue.coarseValue,
        lockWindow: conversionValue == .subscription,
        completionHandler: nil
      )
    } else if #available(iOS 15.4, *) {
      SKAdNetwork.updatePostbackConversionValue(
        conversionValue.fineValue,
        completionHandler: nil
      )
    } else {
      if conversionValue == .install {
        SKAdNetwork.registerAppForAdNetworkAttribution()
      } else {
        SKAdNetwork.updateConversionValue(conversionValue.fineValue)
      }
    }
  }
}
