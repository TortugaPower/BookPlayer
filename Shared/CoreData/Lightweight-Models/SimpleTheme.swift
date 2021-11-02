//
//  SimpleTheme.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 27/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import Foundation
import UIKit

public struct SimpleTheme: Codable {
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

  public let title: String?

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
}

extension SimpleTheme {
  public init(with theme: Theme) {
    self.title = theme.title
    self.lightPrimaryHex = theme.lightPrimaryHex
    self.lightSecondaryHex = theme.lightSecondaryHex
    self.lightAccentHex = theme.lightAccentHex
    self.lightSeparatorHex = theme.lightSeparatorHex
    self.lightSystemBackgroundHex = theme.lightSystemBackgroundHex
    self.lightSecondarySystemBackgroundHex = theme.lightSecondarySystemBackgroundHex
    self.lightTertiarySystemBackgroundHex = theme.lightTertiarySystemBackgroundHex
    self.lightSystemGroupedBackgroundHex = theme.lightSystemGroupedBackgroundHex
    self.lightSystemFillHex = theme.lightSystemFillHex
    self.lightSecondarySystemFillHex = theme.lightSecondarySystemFillHex

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
