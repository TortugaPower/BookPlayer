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
  let showImport: () -> Void

  @State private var listState = ListStateManager()
  @StateObject private var theme = ThemeViewModel()
  @StateObject private var keyboardObserver = KeyboardObserver()
  /// A wire between SwiftUI views that MainCoordinator never touches, so it's owned here.
  /// Injected below, where the integration sheets and the library tab both inherit it.
  @StateObject private var externalImportEvents = ExternalImportEvents()
  @Environment(\.libraryService) private var libraryService
  @Environment(\.playerState) private var playerState
  @Environment(\.syncService) private var syncService
  @Environment(\.jellyfinService) private var jellyfinService
  @Environment(\.audiobookshelfService) private var audiobookshelfService
  @Environment(\.playbackService) private var playbackService
  @Environment(\.colorScheme) private var scheme

  @State private var tabBarContentHeight: CGFloat = 49

  @EnvironmentObject private var listSyncRefreshService: ListSyncRefreshService
  @EnvironmentObject private var playerManager: PlayerManager

  var body: some View {
    TabView {
      Tab("library_title", systemImage: "books.vertical") {
        LibraryRootView(
          showSecondOnboarding: showSecondOnboarding,
          showImport: showImport
        )
        .background {
          TabBarHeightReader { height in
            if tabBarContentHeight != height {
              tabBarContentHeight = height
            }
          }
        }
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(theme.systemBackgroundColor, for: .tabBar)
        .toolbar(listState.isEditing ? .hidden : .visible, for: .tabBar)
        .onDrop(
          of: ImportableItem.readableTypeIdentifiers,
          isTargeted: nil
        ) { providers in
          handleDrop(providers)
          return true
        }
      }
      Tab("profile_title", systemImage: "person.crop.circle") {
        ProfileView()
      }
      Tab("settings_title", systemImage: "gearshape") {
        SettingsView()
      }
      if #available(iOS 26.0, *), UIDevice.current.userInterfaceIdiom == .phone {
        Tab("search_title", systemImage: "magnifyingglass", role: .search) {
          SearchView {
            SearchViewModel(libraryService: libraryService)
          }
        }
      }

    }
    .miniPlayer {
      if !listState.isSearching && !listState.isEditing && !keyboardObserver.isKeyboardVisible,
        let relativePath = playerState.loadedBookRelativePath
      {
        MiniPlayerView(relativePath: relativePath, showPlayer: showPlayer)
          .transition(.move(edge: .bottom).combined(with: .opacity))
          .animation(.spring(), value: playerState.loadedBookRelativePath != nil)
      }
    } accessoryContent: {
      if !listState.isSearching && !listState.isEditing && !keyboardObserver.isKeyboardVisible,
        let relativePath = playerState.loadedBookRelativePath
      {
        MiniPlayerAccessoryView(relativePath: relativePath, showPlayer: showPlayer)
      }
    }
    .sheet(item: $listState.activeIntegrationSheet) { sheet in
      switch sheet {
      case .mediaServers:
        NavigationStack {
          MediaServersView(
            jellyfinService: jellyfinService,
            audiobookshelfService: audiobookshelfService,
            style: .libraryEntry
          )
        }
      }
    }
    .fullScreenCover(isPresented: playerState.isShowingPlayerBinding) {
      PlayerView {
        PlayerViewModel(
          libraryService: libraryService,
          playbackService: playbackService,
          playerManager: playerManager,
          syncService: syncService,
        )
      }
      .presentationBackground(.clear)
      .playbackAlerts(playerState: playerState, playerManager: playerManager, whenPlayerVisible: true)
    }
    // Posted by the failure alert's Media Servers button (PlaybackAlerts) when a book can't
    // play because its media server isn't configured here. Lives at this level because both
    // pieces of state it writes are owned above: the cover has to come down before the sheet
    // can present, since the sheet is attached underneath it.
    .onReceive(NotificationCenter.default.publisher(for: .showMediaServers)) { _ in
      playerState.isShowingPlayer = false
      listState.activeIntegrationSheet = .mediaServers
    }
    // Sibling copy (see PlaybackAlerts): playback also starts with the player CLOSED —
    // mini-player, CarPlay, remote commands, last-book restore — and the copy inside the cover
    // isn't in the hierarchy then, silently dropping the prompt.
    .playbackAlerts(playerState: playerState, playerManager: playerManager, whenPlayerVisible: false)
    // A prompt belongs to the context that raised it and is NOT handed over when the player
    // opens or closes — a deliberate product decision, not a workaround. The two-copy gate
    // exists so exactly one copy can present, not so a prompt can migrate: a question the user
    // was asked against a closed player, re-appearing over an open one after something else
    // (a widget, an intent, Siri) opened it, has lost the context that made it make sense.
    // Dropping it is the conservative half of that trade, and the alert is re-raised by the
    // next attempt anyway.
    .onChange(of: playerState.isShowingPlayer) {
      playerState.clearPrompts()
    }
    // A failure raised while backgrounded outlives the attempt that caused it, so playback
    // succeeding in the meantime has to retire it — otherwise coming back to the app shows an
    // error for something that is playing right now. Only the failure: `.bookPlayed` is what
    // drives the resume prompt in the first place (ExternalProgressService subscribes to it).
    .onReceive(NotificationCenter.default.publisher(for: .bookPlayed)) { _ in
      playerState.pendingFailure = nil
    }
    .accessibilityAction(.magicTap) {
      playerManager.playPause()
    }
    .environment(\.tabBarContentHeight, tabBarContentHeight)
    .environmentObject(theme)
    .environmentObject(externalImportEvents)
    .environment(\.listState, listState)
    .tint(theme.linkColor)
    .onChange(of: scheme) {
      ThemeManager.shared.checkSystemMode()
    }
    .onChange(of: playerState.showPlayer) {
      if playerState.showPlayer {
        showPlayer()
        playerState.showPlayer = false
      }
    }
    // SyncService owns the active/inactive decision (it observes account/subscription
    // changes itself). The view only reacts to sync becoming active to refresh the
    // library list — it no longer writes `isActive`.
    .onChange(of: syncService.isActive) { _, isActive in
      guard isActive else { return }
      Task {
        try? await listSyncRefreshService.syncList(at: nil)
        listState.reloadAll()
      }
    }
  }
  
  func showPlayer() {
    playerState.isShowingPlayer = true
  }
  
  func hasPlayerShown() -> Bool {
    return playerState.isShowingPlayer
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
  MainView {
  } showImport: {
  }
}
