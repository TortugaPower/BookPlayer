//
//  PlayerListPanel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 12/10/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

/// The chapters and bookmarks beside the player, when the screen has room for both, like an
/// open iPhone Duo in landscape
struct PlayerListPanel: View {
  typealias DisplayOption = ListOptionsSectionView.DisplayOption

  let playerManager: PlayerManager
  let libraryService: LibraryServiceProtocol
  let syncService: SyncServiceProtocol

  /// Starts on the list the player's list button opens (Player Controls › Opens)
  @State private var list: DisplayOption =
    UserDefaults.standard.bool(forKey: Constants.UserDefaults.playerListPrefersBookmarks)
    ? .bookmarks
    : .chapters

  var body: some View {
    NavigationStack {
      Group {
        /// Picking a row keeps the panel: there's nothing to close beside the player
        switch list {
        case .chapters:
          ChaptersView {
            ChaptersViewModel(playerManager: playerManager, libraryService: libraryService)
          }
        case .bookmarks:
          BookmarksView {
            BookmarksViewModel(
              playerManager: playerManager,
              libraryService: libraryService,
              syncService: syncService
            )
          }
        }
      }
      /// The player's buttons are plain, which in a list leaves only a row's text tappable;
      /// here the rows keep the whole-row tap and highlight they have in the sheets
      .buttonStyle(.automatic)
      .toolbar {
        ToolbarItem(placement: .principal) {
          /// No label: VoiceOver reads the segments, "Chapters" and "Bookmarks"
          Picker(selection: $list) {
            ForEach(DisplayOption.allCases) { option in
              Text(option.title)
                .tag(option)
            }
          } label: {
            EmptyView()
          }
          .pickerStyle(.segmented)
          .fixedSize()
        }
      }
    }
  }
}

extension View {
  /// On iOS 27.1, puts `PlayerListPanel` beside this view when the screen has room for both;
  /// otherwise the view stays alone, as before
  func playerListPanel(
    playerManager: PlayerManager,
    libraryService: LibraryServiceProtocol,
    syncService: SyncServiceProtocol
  ) -> some View {
    modifier(
      PlayerListPanelModifier(
        playerManager: playerManager,
        libraryService: libraryService,
        syncService: syncService
      )
    )
  }
}

private struct PlayerListPanelModifier: ViewModifier {
  let playerManager: PlayerManager
  let libraryService: LibraryServiceProtocol
  let syncService: SyncServiceProtocol

  func body(content: Content) -> some View {
    if #available(iOS 27.1, *) {
      ArrangementView {
        content
      } secondary: {
        PlayerListPanel(
          playerManager: playerManager,
          libraryService: libraryService,
          syncService: syncService
        )
      }
      /// Side by side only: one above the other, the player and the lists would both be cramped
      .arrangementViewStyle(.split.axes(.horizontal))
    } else {
      content
    }
  }
}
