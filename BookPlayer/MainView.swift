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

  @State private var listState = ListStateManager()
  @StateObject private var theme = ThemeViewModel()
  @Environment(\.playerState) private var playerState
  @Environment(\.syncService) private var syncService
  @Environment(\.accountService) private var accountService
  @Environment(\.colorScheme) private var scheme

  @EnvironmentObject private var listSyncRefreshService: ListSyncRefreshService

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
        .onDrop(
          of: ImportableItem.readableTypeIdentifiers,
          isTargeted: nil
        ) { providers in
          handleDrop(providers)
          return true
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
      .toolbar(listState.isEditing ? .hidden : .visible, for: .tabBar)
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      if !listState.isSearching && !listState.isEditing,
         let relativePath = playerState.loadedBookRelativePath {
        MiniPlayerView(relativePath: relativePath, showPlayer: showPlayer)
          .transition(.move(edge: .bottom).combined(with: .opacity))
          .animation(.spring(), value: playerState.loadedBookRelativePath != nil)
      }
    }
    .environmentObject(theme)
    .environment(\.listState, listState)
    .tint(theme.linkColor)
    .onChange(of: scheme) {
      ThemeManager.shared.checkSystemMode()
    }
    .onReceive(
      NotificationCenter.default.publisher(for: .accountUpdate, object: nil)
    ) { _ in
      guard accountService.hasAccount() else { return }

      if accountService.hasSyncEnabled() {
        if !syncService.isActive {
          syncService.isActive = true
          Task {
            try? await listSyncRefreshService.syncList(at: nil)
            listState.reloadAll()
          }
        }
      } else if syncService.isActive {
        syncService.isActive = false
        syncService.cancelAllJobs()
      }
    }
  }

  func handleDrop(_ providers: [NSItemProvider]) {
    for provider in providers {
      let suggestedName = provider.suggestedName
      provider.loadObject(ofClass: ImportableItem.self) { [suggestedName] (object, _) in
        guard let item = object as? ImportableItem else { return }
        /// Set `suggesteName` from the provider
        item.suggestedName = suggestedName

        importData(from: item)
      }
    }
  }

  func importData(from item: ImportableItem) {
    let filename: String

    if let suggestedName = item.suggestedName {
      let pathExtension = (suggestedName as NSString).pathExtension
      /// Use  `suggestedFileExtension` only if the curret name does not include an extension
      if pathExtension.isEmpty {
        filename = "\(suggestedName).\(item.suggestedFileExtension)"
      } else {
        filename = suggestedName
      }
    } else {
      /// Fallback if the provider didn't have a suggested name
      filename = "\(Date().timeIntervalSince1970).\(item.suggestedFileExtension)"
    }

    let destinationURL = DataManager.getDocumentsFolderURL()
      .appendingPathComponent(filename)

    do {
      try item.data.write(to: destinationURL)
    } catch {
      print("Fail to move dropped file to the Documents directory: \(error.localizedDescription)")
    }
  }
}

#Preview {
  MainView {} showPlayer: {} showImport: {}
}
