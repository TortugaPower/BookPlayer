//
//  SimpleTheme.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 27/9/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import Foundation
import UIKit

public struct SimpleTheme: Codable, Identifiable {
  public var id: String { title }
  public var useDarkVariant: Bool = false

  public let lightPrimaryHex: String
  public let lightSecondaryHex: String
  public let lightAccentHex: String
  public let lightSeparatorHex: String
  public let lightSystemBackgroundHex: String
  public let lightSecondarySystemBackgroundHex: String
  public let lightTertiarySystemBackgroundHex: String
  public let lightSystemGroupedBackgroundHex: String
  public let lightSystemFillHex: String
  public let lightSecondarySystemFillHex: String
  public let lightTertiarySystemFillHex: String
  public let lightQuaternarySystemFillHex: String
  public let darkPrimaryHex: String
  public let darkSecondaryHex: String
  public let darkAccentHex: String
  public let darkSeparatorHex: String
  public let darkSystemBackgroundHex: String
  public let darkSecondarySystemBackgroundHex: String
  public let darkTertiarySystemBackgroundHex: String
  public let darkSystemGroupedBackgroundHex: String
  public let darkSystemFillHex: String
  public let darkSecondarySystemFillHex: String
  public let darkTertiarySystemFillHex: String
  public let darkQuaternarySystemFillHex: String
  public let locked: Bool

  public let title: String

  public var lightPrimaryColor: UIColor {
    return UIColor(hex: lightPrimaryHex)
  }

  public var lightSecondaryColor: UIColor {
    return UIColor(hex: lightSecondaryHex)
  }

  public var lightLinkColor: UIColor {
    return UIColor(hex: lightAccentHex)
  }

  public var lightSystemBackgroundColor: UIColor {
    return UIColor(hex: lightSystemBackgroundHex)
  }

  public var primaryColor: UIColor {
    let hex: String = self.useDarkVariant
    ? darkPrimaryHex
    : lightPrimaryHex
    return UIColor(hex: hex)
  }

  public var secondaryColor: UIColor {
    let hex: String = self.useDarkVariant
    ? darkSecondaryHex
    : lightSecondaryHex
    return UIColor(hex: hex)
  }

  public var linkColor: UIColor {
    let hex: String = self.useDarkVariant
    ? darkAccentHex
    : lightAccentHex
    return UIColor(hex: hex)
  }

  public var separatorColor: UIColor {
    let hex: String = self.useDarkVariant
    ? darkSeparatorHex
    : lightSeparatorHex
    return UIColor(hex: hex)
  }

  public var systemBackgroundColor: UIColor {
    let hex: String = self.useDarkVariant
    ? darkSystemBackgroundHex
    : lightSystemBackgroundHex
    return UIColor(hex: hex)
  }

  public var secondarySystemBackgroundColor: UIColor {
    let hex: String = self.useDarkVariant
    ? darkSecondarySystemBackgroundHex
    : lightSecondarySystemBackgroundHex
    return UIColor(hex: hex)
  }

  public var tertiarySystemBackgroundColor: UIColor {
    let hex: String = self.useDarkVariant
    ? darkTertiarySystemBackgroundHex
    : lightTertiarySystemBackgroundHex
    return UIColor(hex: hex)
  }

  public var systemGroupedBackgroundColor: UIColor {
    let hex: String = self.useDarkVariant
    ? darkSystemGroupedBackgroundHex
    : lightSystemGroupedBackgroundHex
    return UIColor(hex: hex)
  }

  public var systemFillColor: UIColor {
    let hex: String = self.useDarkVariant
    ? darkSystemFillHex
    : lightSystemFillHex
    return UIColor(hex: hex)
  }

  public var secondarySystemFillColor: UIColor {
    let hex: String = self.useDarkVariant
    ? darkSecondarySystemFillHex
    : lightSecondarySystemFillHex
    return UIColor(hex: hex)
  }

  public var tertiarySystemFillColor: UIColor {
    let hex: String = self.useDarkVariant
    ? darkTertiarySystemFillHex
    : lightTertiarySystemFillHex
    return UIColor(hex: hex)
  }

  public var quaternarySystemFillColor: UIColor {
    let hex: String = self.useDarkVariant
    ? darkQuaternarySystemFillHex
    : lightQuaternarySystemFillHex
    return UIColor(hex: hex)
  }

  enum CodingKeys: String, CodingKey {
    case title, lightPrimaryHex, lightSecondaryHex, lightAccentHex, lightSeparatorHex, lightSystemBackgroundHex, lightSecondarySystemBackgroundHex, lightTertiarySystemBackgroundHex, lightSystemGroupedBackgroundHex, lightSystemFillHex, lightSecondarySystemFillHex, lightTertiarySystemFillHex, lightQuaternarySystemFillHex, darkPrimaryHex, darkSecondaryHex, darkAccentHex, darkSeparatorHex, darkSystemBackgroundHex, darkSecondarySystemBackgroundHex, darkTertiarySystemBackgroundHex, darkSystemGroupedBackgroundHex, darkSystemFillHex, darkSecondarySystemFillHex, darkTertiarySystemFillHex, darkQuaternarySystemFillHex, locked
  }

  public init(
    useDarkVariant: Bool,
    lightPrimaryHex: String,
    lightSecondaryHex: String,
    lightAccentHex: String,
    lightSeparatorHex: String,
    lightSystemBackgroundHex: String,
    lightSecondarySystemBackgroundHex: String,
    lightTertiarySystemBackgroundHex: String,
    lightSystemGroupedBackgroundHex: String,
    lightSystemFillHex: String,
    lightSecondarySystemFillHex: String,
    lightTertiarySystemFillHex: String,
    lightQuaternarySystemFillHex: String,
    darkPrimaryHex: String,
    darkSecondaryHex: String,
    darkAccentHex: String,
    darkSeparatorHex: String,
    darkSystemBackgroundHex: String,
    darkSecondarySystemBackgroundHex: String,
    darkTertiarySystemBackgroundHex: String,
    darkSystemGroupedBackgroundHex: String,
    darkSystemFillHex: String,
    darkSecondarySystemFillHex: String,
    darkTertiarySystemFillHex: String,
    darkQuaternarySystemFillHex: String,
    locked: Bool,
    title: String
  ) {
    self.useDarkVariant = useDarkVariant
    self.lightPrimaryHex = lightPrimaryHex
    self.lightSecondaryHex = lightSecondaryHex
    self.lightAccentHex = lightAccentHex
    self.lightSeparatorHex = lightSeparatorHex
    self.lightSystemBackgroundHex = lightSystemBackgroundHex
    self.lightSecondarySystemBackgroundHex = lightSecondarySystemBackgroundHex
    self.lightTertiarySystemBackgroundHex = lightTertiarySystemBackgroundHex
    self.lightSystemGroupedBackgroundHex = lightSystemGroupedBackgroundHex
    self.lightSystemFillHex = lightSystemFillHex
    self.lightSecondarySystemFillHex = lightSecondarySystemFillHex
    self.lightTertiarySystemFillHex = lightTertiarySystemFillHex
    self.lightQuaternarySystemFillHex = lightQuaternarySystemFillHex
    self.darkPrimaryHex = darkPrimaryHex
    self.darkSecondaryHex = darkSecondaryHex
    self.darkAccentHex = darkAccentHex
    self.darkSeparatorHex = darkSeparatorHex
    self.darkSystemBackgroundHex = darkSystemBackgroundHex
    self.darkSecondarySystemBackgroundHex = darkSecondarySystemBackgroundHex
    self.darkTertiarySystemBackgroundHex = darkTertiarySystemBackgroundHex
    self.darkSystemGroupedBackgroundHex = darkSystemGroupedBackgroundHex
    self.darkSystemFillHex = darkSystemFillHex
    self.darkSecondarySystemFillHex = darkSecondarySystemFillHex
    self.darkTertiarySystemFillHex = darkTertiarySystemFillHex
    self.darkQuaternarySystemFillHex = darkQuaternarySystemFillHex
    self.locked = locked
    self.title = title
  }
}

extension SimpleTheme {
  // swiftlint:disable all
  public init(with theme: Theme) {
    if theme.title != nil {
      self.title = theme.title
    } else {
      self.title = "Default / Dark"
    }

    if theme.lightPrimaryHex != nil {
      self.lightPrimaryHex = theme.lightPrimaryHex
    } else {
      self.lightPrimaryHex = "242320"
    }

    if theme.lightSecondaryHex != nil {
      self.lightSecondaryHex = theme.lightSecondaryHex
    } else {
      self.lightSecondaryHex = "8F8E95"
    }

    if theme.lightAccentHex != nil {
      self.lightAccentHex = theme.lightAccentHex
    } else {
      self.lightAccentHex = "3488D1"
    }

    if theme.lightSeparatorHex != nil {
      self.lightSeparatorHex = theme.lightSeparatorHex
    } else {
      self.lightSeparatorHex = "DCDCDC"
    }

    if theme.lightSystemBackgroundHex != nil {
      self.lightSystemBackgroundHex = theme.lightSystemBackgroundHex
    } else {
      self.lightSystemBackgroundHex = "FAFAFA"
    }

    if theme.lightSecondarySystemBackgroundHex != nil {
      self.lightSecondarySystemBackgroundHex = theme.lightSecondarySystemBackgroundHex
    } else {
      self.lightSecondarySystemBackgroundHex = "FCFBFC"
    }

    if theme.lightTertiarySystemBackgroundHex != nil {
      self.lightTertiarySystemBackgroundHex = theme.lightTertiarySystemBackgroundHex
    } else {
      self.lightTertiarySystemBackgroundHex = "E8E7E9"
    }

    if theme.lightSystemGroupedBackgroundHex != nil {
      self.lightSystemGroupedBackgroundHex = theme.lightSystemGroupedBackgroundHex
    } else {
      self.lightSystemGroupedBackgroundHex = "EFEEF0"
    }

    if theme.lightSystemFillHex != nil {
      self.lightSystemFillHex = theme.lightSystemFillHex
    } else {
      self.lightSystemFillHex = "87A0BA"
    }

    if theme.lightSecondarySystemFillHex != nil {
      self.lightSecondarySystemFillHex = theme.lightSecondarySystemFillHex
    } else {
      self.lightSecondarySystemFillHex = "ACAAB1"
    }

    if theme.lightTertiarySystemFillHex != nil {
      self.lightTertiarySystemFillHex = theme.lightTertiarySystemFillHex
    } else {
      self.lightTertiarySystemFillHex = "3488D1"
    }

    if theme.lightQuaternarySystemFillHex != nil {
      self.lightQuaternarySystemFillHex = theme.lightQuaternarySystemFillHex
    } else {
      self.lightQuaternarySystemFillHex = "3488D1"
    }

    if theme.darkPrimaryHex != nil {
      self.darkPrimaryHex = theme.darkPrimaryHex
    } else {
      self.darkPrimaryHex = "FAFBFC"
    }

    if theme.darkSecondaryHex != nil {
      self.darkSecondaryHex = theme.darkSecondaryHex
    } else {
      self.darkSecondaryHex = "8F8E94"
    }

    if theme.darkAccentHex != nil {
      self.darkAccentHex = theme.darkAccentHex
    } else {
      self.darkAccentHex = "459EEC"
    }

    if theme.darkSeparatorHex != nil {
      self.darkSeparatorHex = theme.darkSeparatorHex
    } else {
      self.darkSeparatorHex = "434448"
    }

    if theme.darkSystemBackgroundHex != nil {
      self.darkSystemBackgroundHex = theme.darkSystemBackgroundHex
    } else {
      self.darkSystemBackgroundHex = "202225"
    }

    if theme.darkSecondarySystemBackgroundHex != nil {
      self.darkSecondarySystemBackgroundHex = theme.darkSecondarySystemBackgroundHex
    } else {
      self.darkSecondarySystemBackgroundHex = "111113"
    }

    if theme.darkTertiarySystemBackgroundHex != nil {
      self.darkTertiarySystemBackgroundHex = theme.darkTertiarySystemBackgroundHex
    } else {
      self.darkTertiarySystemBackgroundHex = "333538"
    }

    if theme.darkSystemGroupedBackgroundHex != nil {
      self.darkSystemGroupedBackgroundHex = theme.darkSystemGroupedBackgroundHex
    } else {
      self.darkSystemGroupedBackgroundHex = "2C2D30"
    }

    if theme.darkSystemFillHex != nil {
      self.darkSystemFillHex = theme.darkSystemFillHex
    } else {
      self.darkSystemFillHex = "647E98"
    }

    if theme.darkSecondarySystemFillHex != nil {
      self.darkSecondarySystemFillHex = theme.darkSecondarySystemFillHex
    } else {
      self.darkSecondarySystemFillHex = "707176"
    }

    if theme.darkTertiarySystemFillHex != nil {
      self.darkTertiarySystemFillHex = theme.darkTertiarySystemFillHex
    } else {
      self.darkTertiarySystemFillHex = "459EEC"
    }

    if theme.darkQuaternarySystemFillHex != nil {
      self.darkQuaternarySystemFillHex = theme.darkQuaternarySystemFillHex
    } else {
      self.darkQuaternarySystemFillHex = "459EEC"
    }

    self.locked = theme.locked
  }
  // swiftlint:enable all

  public init(with theme: SimpleTheme, useDarkVariant: Bool) {
    self.title = theme.title
    self.lightPrimaryHex = theme.lightPrimaryHex
    self.lightSecondaryHex = theme.lightSecondaryHex
    self.lightAccentHex = theme.lightAccentHex
    self.lightSeparatorHex = theme.lightSecondaryHex
    self.lightSystemBackgroundHex = theme.lightSystemBackgroundHex
    self.lightSecondarySystemBackgroundHex = theme.lightSecondarySystemBackgroundHex
    self.lightTertiarySystemBackgroundHex = theme.lightTertiarySystemBackgroundHex
    self.lightSystemGroupedBackgroundHex = theme.lightSystemGroupedBackgroundHex
    self.lightSystemFillHex = theme.lightSystemFillHex
    self.lightSecondarySystemFillHex = theme.lightSecondarySystemFillHex
    self.lightTertiarySystemFillHex = theme.lightTertiarySystemFillHex
    self.lightQuaternarySystemFillHex = theme.lightQuaternarySystemFillHex
    self.darkPrimaryHex = theme.darkPrimaryHex
    self.darkSecondaryHex = theme.darkSecondaryHex
    self.darkAccentHex = theme.darkAccentHex
    self.darkSeparatorHex = theme.darkSeparatorHex
    self.darkSystemBackgroundHex = theme.darkSystemBackgroundHex
    self.darkSecondarySystemBackgroundHex = theme.darkSecondarySystemBackgroundHex
    self.darkTertiarySystemBackgroundHex = theme.darkTertiarySystemBackgroundHex
    self.darkSystemGroupedBackgroundHex = theme.darkSystemGroupedBackgroundHex
    self.darkSystemFillHex = theme.darkSystemFillHex
    self.darkSecondarySystemFillHex = theme.darkSecondarySystemFillHex
    self.darkTertiarySystemFillHex = theme.darkTertiarySystemFillHex
    self.darkQuaternarySystemFillHex = theme.darkQuaternarySystemFillHex
    self.locked = theme.locked
    self.useDarkVariant = useDarkVariant
  }
}

extension SimpleTheme: Equatable {
  public static func == (lhs: SimpleTheme, rhs: SimpleTheme) -> Bool {
    return lhs.title == rhs.title
  }
}

extension SimpleTheme {
  public static func getDefaultTheme(useDarkVariant: Bool = false) -> SimpleTheme {
    return SimpleTheme(
      useDarkVariant: useDarkVariant,
      lightPrimaryHex: "242320",
      lightSecondaryHex: "8F8E95",
      lightAccentHex: "3488D1",
      lightSeparatorHex: "DCDCDC",
      lightSystemBackgroundHex: "FAFAFA",
      lightSecondarySystemBackgroundHex: "FCFBFC",
      lightTertiarySystemBackgroundHex: "E8E7E9",
      lightSystemGroupedBackgroundHex: "EFEEF0",
      lightSystemFillHex: "87A0BA",
      lightSecondarySystemFillHex: "ACAAB1",
      lightTertiarySystemFillHex: "3488D1",
      lightQuaternarySystemFillHex: "3488D1",
      darkPrimaryHex: "FAFBFC",
      darkSecondaryHex: "8F8E94",
      darkAccentHex: "459EEC",
      darkSeparatorHex: "434448",
      darkSystemBackgroundHex: "202225",
      darkSecondarySystemBackgroundHex: "111113",
      darkTertiarySystemBackgroundHex: "333538",
      darkSystemGroupedBackgroundHex: "2C2D30",
      darkSystemFillHex: "647E98",
      darkSecondarySystemFillHex: "707176",
      darkTertiarySystemFillHex: "459EEC",
      darkQuaternarySystemFillHex: "459EEC",
      locked: false,
      title: "Default / Dark"
    )
  }
}
