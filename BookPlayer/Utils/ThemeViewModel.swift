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

@MainActor
class ThemeViewModel: ObservableObject, Themeable {
  @Published var theme: SimpleTheme
  @Published var defaultArtwork: Image?

  init() {
    // Initialize with current theme from ThemeManager for consistency
    theme = ThemeManager.shared.currentTheme
    setUpTheming()
  }

  func applyTheme(_ theme: SimpleTheme) {
    self.theme = theme

    if let artwork = ArtworkService.generateDefaultArtwork(from: theme.linkColor) {
      defaultArtwork = Image(uiImage: artwork)
    }
  }

  var title: String { theme.title }

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

  /// Semantic color for error glyphs (e.g. the warning triangle in the Quick Connect failure state).
  ///
  /// A deliberate system-semantic constant, **not** theme-derived — unlike every other property here it
  /// never reads `theme`, so a theme cannot currently override it. It lives on this type as the single
  /// place to migrate the app's scattered `.red` literals onto; making it genuinely themeable means
  /// adding an error color to `SimpleTheme` first. `systemRed` adapts to dark mode and satisfies WCAG AA
  /// contrast against both system backgrounds.
  var errorColor: Color {
    return Color(uiColor: .systemRed)
  }
}
