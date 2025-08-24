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
  @State private var selection: BPTabItem = .library
  @State private var isFirstLoad: Bool = true
  @State private var loadingState = LoadingOverlayState()

  @StateObject private var theme = ThemeViewModel()
  @EnvironmentObject private var playerManager: PlayerManager

  @Environment(\.libraryService) private var libraryService
  @Environment(\.playerLoaderService) private var playerLoaderService
  @Environment(\.playerState) private var playerState
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    TabView(selection: $selection) {
      Group {
        LibraryRootView {} showPlayer: {} showImport: {}
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
    .sheet(isPresented: playerState.showPlayerBinding) {
      Text("Player")
    }
    .environment(\.loadingState, loadingState)
    .environmentObject(theme)
    .tint(theme.linkColor)
    .onChange(of: scheme) {
      ThemeManager.shared.checkSystemMode()
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      if playerState.loadedBookRelativePath != nil {
        HStack {
          Spacer()
          Button {
            playerState.showPlayerBinding.wrappedValue = true
          } label: {
            Label("Quick Action", systemImage: "bolt.fill")
              .font(.headline)
              .padding(.horizontal, 16)
              .padding(.vertical, 12)
          }
          .background(.thinMaterial)
          .clipShape(Capsule())
          .shadow(radius: 6)
          .accessibilityAddTraits(.isButton)
          Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 49 + 12)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(), value: playerState.loadedBookRelativePath != nil)
      }
    }
    .onAppear {
      guard isFirstLoad else { return }

      isFirstLoad = false

    }
  }

  func loadLastBookIfNeeded() async {
    guard
      let libraryItem = libraryService.getLibraryLastItem()
    else { return }

    do {
      try await playerLoaderService.loadPlayer(
        libraryItem.relativePath,
        autoplay: false,
        recordAsLastBook: false
      )
      if UserDefaults.standard.bool(forKey: Constants.UserActivityPlayback) {
        UserDefaults.standard.removeObject(forKey: Constants.UserActivityPlayback)
        self.playerManager.play()
      }

      if UserDefaults.standard.bool(forKey: Constants.UserDefaults.showPlayer) {
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaults.showPlayer)
        //        self.showPlayer()
      }
    } catch {
      loadingState.error = error
    }
  }
}

#Preview {
  MainView()
}
