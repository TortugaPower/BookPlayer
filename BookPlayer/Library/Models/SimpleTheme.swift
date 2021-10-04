//
//  SimpleTheme.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 27/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import Foundation
import UIKit
import BookPlayerKit

struct SimpleTheme: Codable {
  var useDarkVariant: Bool = false

  let lightPrimaryHex: String
  let lightSecondaryHex: String
  let lightAccentHex: String
  let lightSeparatorHex: String
  let lightSystemBackgroundHex: String
  let lightSecondarySystemBackgroundHex: String
  let lightTertiarySystemBackgroundHex: String
  let lightSystemGroupedBackgroundHex: String
  let lightSystemFillHex: String
  let lightSecondarySystemFillHex: String
  let lightTertiarySystemFillHex: String
  let lightQuaternarySystemFillHex: String
  let darkPrimaryHex: String
  let darkSecondaryHex: String
  let darkAccentHex: String
  let darkSeparatorHex: String
  let darkSystemBackgroundHex: String
  let darkSecondarySystemBackgroundHex: String
  let darkTertiarySystemBackgroundHex: String
  let darkSystemGroupedBackgroundHex: String
  let darkSystemFillHex: String
  let darkSecondarySystemFillHex: String
  let darkTertiarySystemFillHex: String
  let darkQuaternarySystemFillHex: String
  let locked: Bool

  let title: String?

  var lightPrimaryColor: UIColor {
      return UIColor(hex: lightPrimaryHex)
  }

  var lightSecondaryColor: UIColor {
      return UIColor(hex: lightSecondaryHex)
  }

  var lightLinkColor: UIColor {
      return UIColor(hex: lightAccentHex)
  }

  var lightSystemBackgroundColor: UIColor {
      return UIColor(hex: lightSystemBackgroundHex)
  }

  var primaryColor: UIColor {
      let hex: String = self.useDarkVariant
          ? darkPrimaryHex
          : lightPrimaryHex
      return UIColor(hex: hex)
  }

  var secondaryColor: UIColor {
      let hex: String = self.useDarkVariant
          ? darkSecondaryHex
          : lightSecondaryHex
      return UIColor(hex: hex)
  }

  var linkColor: UIColor {
      let hex: String = self.useDarkVariant
          ? darkAccentHex
          : lightAccentHex
      return UIColor(hex: hex)
  }

  var separatorColor: UIColor {
      let hex: String = self.useDarkVariant
          ? darkSeparatorHex
          : lightSeparatorHex
      return UIColor(hex: hex)
  }

  var systemBackgroundColor: UIColor {
      let hex: String = self.useDarkVariant
          ? darkSystemBackgroundHex
          : lightSystemBackgroundHex
      return UIColor(hex: hex)
  }

  var secondarySystemBackgroundColor: UIColor {
      let hex: String = self.useDarkVariant
          ? darkSecondarySystemBackgroundHex
          : lightSecondarySystemBackgroundHex
      return UIColor(hex: hex)
  }

  var tertiarySystemBackgroundColor: UIColor {
      let hex: String = self.useDarkVariant
          ? darkTertiarySystemBackgroundHex
          : lightTertiarySystemBackgroundHex
      return UIColor(hex: hex)
  }

  var systemGroupedBackgroundColor: UIColor {
      let hex: String = self.useDarkVariant
          ? darkSystemGroupedBackgroundHex
          : lightSystemGroupedBackgroundHex
      return UIColor(hex: hex)
  }

  var systemFillColor: UIColor {
      let hex: String = self.useDarkVariant
          ? darkSystemFillHex
          : lightSystemFillHex
      return UIColor(hex: hex)
  }

  var secondarySystemFillColor: UIColor {
      let hex: String = self.useDarkVariant
          ? darkSecondarySystemFillHex
          : lightSecondarySystemFillHex
      return UIColor(hex: hex)
  }

  var tertiarySystemFillColor: UIColor {
      let hex: String = self.useDarkVariant
          ? darkTertiarySystemFillHex
          : lightTertiarySystemFillHex
      return UIColor(hex: hex)
  }

  var quaternarySystemFillColor: UIColor {
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
  init(with theme: Theme) {
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
  }

  init(with theme: SimpleTheme, useDarkVariant: Bool) {
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
  static func == (lhs: SimpleTheme, rhs: SimpleTheme) -> Bool {
    return lhs.title == rhs.title
  }
}
