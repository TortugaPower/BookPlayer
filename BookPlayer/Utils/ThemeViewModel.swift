//
//  ThemeViewModel.swift
//  BookPlayer
//
//  Created by gianni.carlo on 4/12/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation
import SwiftUI
import Themeable

class ThemeViewModel: ObservableObject, Themeable {
  @Published var theme: SimpleTheme

  init() {
    theme = SimpleTheme.getDefaultTheme(useDarkVariant: UIScreen.main.traitCollection.userInterfaceStyle == .dark)
    setUpTheming()
  }

  func applyTheme(_ theme: SimpleTheme) {
    self.theme = theme
  }

  var useDarkVariant: Bool {
    return theme.useDarkVariant
  }

  var primaryColor: Color {
    return Color(theme.primaryColor)
  }

  var secondaryColor: Color {
    return Color(theme.secondaryColor)
  }

  var linkColor: Color {
    return Color(theme.linkColor)
  }

  var separatorColor: Color {
    return Color(theme.separatorColor)
  }

  var systemBackgroundColor: Color {
    return Color(theme.systemBackgroundColor)
  }

  var secondarySystemBackgroundColor: Color {
    return Color(theme.secondarySystemBackgroundColor)
  }

  var tertiarySystemBackgroundColor: Color {
    return Color(theme.tertiarySystemBackgroundColor)
  }

  var systemGroupedBackgroundColor: Color {
    return Color(theme.systemGroupedBackgroundColor)
  }

  var systemFillColor: Color {
    return Color(theme.systemFillColor)
  }

  var secondarySystemFillColor: Color {
    return Color(theme.secondarySystemFillColor)
  }

  var tertiarySystemFillColor: Color {
    return Color(theme.tertiarySystemFillColor)
  }

  var quaternarySystemFillColor: Color {
    return Color(theme.quaternarySystemFillColor)
  }
}
