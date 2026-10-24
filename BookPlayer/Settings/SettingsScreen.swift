//
//  SettingsScreen.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 19/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import Foundation
import SwiftUI

enum SettingsScreen: String, Hashable {
  case themes, icons
  case controls, autoplay, autolock
  case storage, syncbackup
  case shortcuts
  case mediaServers, hardcover
  case tipjar
  case credits
}

extension EnvironmentValues {
  /// The screen shown beside the Settings list on a wide screen, so its row can stand out
  @Entry var selectedSettingsScreen: SettingsScreen?
}

extension View {
  /// The themed row background, tinted while `screen` is the one shown beside the list. The
  /// list can't highlight it: a row background replaces the system's selection
  func settingsRowBackground(for screen: SettingsScreen) -> some View {
    modifier(SettingsRowBackground(screen: screen))
  }
}

private struct SettingsRowBackground: ViewModifier {
  let screen: SettingsScreen
  @Environment(\.selectedSettingsScreen) private var selectedScreen
  @EnvironmentObject private var theme: ThemeViewModel

  func body(content: Content) -> some View {
    content
      .listRowBackground(
        /// As a grouped list marks its selection: about 7% of the text color over the row, so a
        /// light theme darkens it a little and a dark one lightens it
        theme.tertiarySystemBackgroundColor
          .overlay(selectedScreen == screen ? theme.primaryColor.opacity(0.07) : .clear)
      )
  }
}
