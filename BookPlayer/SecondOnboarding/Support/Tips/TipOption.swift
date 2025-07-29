//
//  TipOption.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 3/2/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import Foundation
import SwiftUI

enum TipOption: String, Identifiable, CaseIterable {
  public var id: Self { self }
  case kind = "com.tortugapower.audiobookplayer.tip.kind"
  case excellent = "com.tortugapower.audiobookplayer.tip.excellent"
  case incredible = "com.tortugapower.audiobookplayer.tip.incredible"

  var title: String {
    switch self {
    case .kind:
      return "Kind\ntip of"
    case .excellent:
      return "Excellent\ntip of"
    case .incredible:
      return "Incredible\ntip of"
    }
  }

  var localizedTitle: LocalizedStringKey {
    switch self {
    case .kind:
      return "kind_tip_title"
    case .excellent:
      return "excellent_tip_title"
    case .incredible:
      return "incredible_tip_title"
    }
  }

  var price: String {
    switch self {
    case .kind:
      return "$2.99"
    case .excellent:
      return "$4.99"
    case .incredible:
      return "$9.99"
    }
  }
}
