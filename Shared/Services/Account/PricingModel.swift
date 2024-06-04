//
//  PricingModel.swift
//  BookPlayer
//
//  Created by gianni.carlo on 2/5/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import SwiftUI

public struct PricingModel: Identifiable, Equatable {
  public var id: String
  public let title: String

  public init(id: String, title: String) {
    self.id = id
    self.title = title
  }
}

public enum PricingOption: String, Identifiable, Codable {
  public var id: Self { self }

  public static func parseValue(_ value: Int) -> Self? {
    switch value {
    case 3:
      return .supportTier3
    case 4:
      return .supportTier4
    case 5:
      return .proMonthly
    case 6:
      return .supportTier6
    case 7:
      return .supportTier7
    case 8:
      return .supportTier8
    case 9:
      return .supportTier9
    case 10:
      return .supportTier10
    default:
      return nil
    }
  }

  case proMonthly = "com.tortugapower.audiobookplayer.subscription.pro"
  case proYearly = "com.tortugapower.audiobookplayer.subscription.pro.yearly"
  case supportTier3 = "com.tortugapower.audiobookplayer.subscription.support.3"
  case supportTier4 = "com.tortugapower.audiobookplayer.subscription.support.4"
  case supportTier6 = "com.tortugapower.audiobookplayer.subscription.support.6"
  case supportTier7 = "com.tortugapower.audiobookplayer.subscription.support.7"
  case supportTier8 = "com.tortugapower.audiobookplayer.subscription.support.8"
  case supportTier9 = "com.tortugapower.audiobookplayer.subscription.support.9"
  case supportTier10 = "com.tortugapower.audiobookplayer.subscription.support.10"

  public var title: String {
    switch self {
    case .proMonthly:
      return "$4.99"
    case .proYearly:
      return "$49.99"
    case .supportTier3:
      return "$2.99"
    case .supportTier4:
      return "$3.99"
    case .supportTier6:
      return "$5.99"
    case .supportTier7:
      return "$6.99"
    case .supportTier8:
      return "$7.99"
    case .supportTier9:
      return "$8.99"
    case .supportTier10:
      return "$9.99"
    }
  }

  public var cost: Double {
    switch self {
    case .proMonthly:
      return 4.99
    case .proYearly:
      return 49.99
    case .supportTier3:
      return 2.99
    case .supportTier4:
      return 3.99
    case .supportTier6:
      return 5.99
    case .supportTier7:
      return 6.99
    case .supportTier8:
      return 7.99
    case .supportTier9:
      return 8.99
    case .supportTier10:
      return 9.99
    }
  }
}
