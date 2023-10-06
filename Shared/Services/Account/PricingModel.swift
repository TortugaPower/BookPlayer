//
//  PricingModel.swift
//  BookPlayer
//
//  Created by gianni.carlo on 2/5/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import SwiftUI
import RevenueCat

public struct PricingModel: Identifiable, Equatable, Hashable {
  public let id: SubscriptionID
  public let title: String

  public init?(_ product: StoreProduct) {
    guard
      let id = SubscriptionID(rawValue: product.productIdentifier)
    else {
      return nil
    }
    self.id = id
    self.title = "\(product.localizedPriceString) \("monthly_title".localized)"
  }

  private init(id: SubscriptionID, title: String) {
    self.id = id
    self.title = title
  }

  static public let hardcodedOptions = [
    PricingModel(id: .yearly, 
                 title: "49.99 USD \("yearly_title".localized)"),
    PricingModel(id: .monthly, 
                 title: "4.99 USD \("monthly_title".localized)")]
}

public enum SubscriptionID: String, CaseIterable {
  case yearly = "com.tortugapower.audiobookplayer.subscription.pro.yearly"
  case monthly = "com.tortugapower.audiobookplayer.subscription.pro"
}
