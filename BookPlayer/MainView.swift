//
//  MainView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 12/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct MainView: View {
  let showSecondOnboarding: () -> Void
  let showPlayer: () -> Void
  let showImport: () -> Void

  @StateObject private var theme = ThemeViewModel()
  @Environment(\.playerState) private var playerState
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    TabView {
      Group {
        LibraryRootView(
          showSecondOnboarding: showSecondOnboarding,
          showPlayer: showPlayer,
          showImport: showImport
        )
        .tag(BPTabItem.library)
        .tabItem {
          Label("library_title", systemImage: "books.vertical")
        }
        ProfileView()
          .tag(BPTabItem.profile)
          .tabItem {
            Label("profile_title", systemImage: "person.crop.circle")
          }
        SettingsView()
          .tag(BPTabItem.settings)
          .tabItem {
            Label("settings_title", systemImage: "gearshape")
          }
      }
      .toolbarBackground(.visible, for: .tabBar)
      .toolbarBackground(theme.systemBackgroundColor, for: .tabBar)
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      if let relativePath = playerState.loadedBookRelativePath {
        MiniPlayerView(relativePath: relativePath, showPlayer: showPlayer)
          .transition(.move(edge: .bottom).combined(with: .opacity))
          .animation(.spring(), value: playerState.loadedBookRelativePath != nil)
      }
    }
    .environmentObject(theme)
    .tint(theme.linkColor)
    .onChange(of: scheme) {
      ThemeManager.shared.checkSystemMode()
    }
  }
}

#Preview {
  MainView {} showPlayer: {} showImport: {}
}
