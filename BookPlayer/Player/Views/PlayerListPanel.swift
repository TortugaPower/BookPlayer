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
        switch list {
        case .chapters:
          ChaptersView(isBesidePlayer: true) {
            ChaptersViewModel(playerManager: playerManager, libraryService: libraryService)
          }
        case .bookmarks:
          BookmarksView(isBesidePlayer: true) {
            BookmarksViewModel(
              playerManager: playerManager,
              libraryService: libraryService,
              syncService: syncService
            )
          }
        }
      }
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

/// Tells a view inside the player whether `PlayerListPanel` is beside it. Only views inside the
/// player can tell: `ArrangementView` doesn't pass the arrangement to the player's outermost view
/// or its modifiers
struct PlayerListPanelReader<Content: View>: View {
  @ViewBuilder let content: (_ isPanelShown: Bool) -> Content

  var body: some View {
    if #available(iOS 27.1, *) {
      SplitAxisReader { axis in
        /// Horizontal while the panel shows; with the player alone (iPhone Duo closed, or open
        /// in portrait) it reads vertical
        content(axis == .horizontal)
      }
    } else {
      content(false)
    }
  }
}

/// Passes on how `ArrangementView` placed its two sides
@available(iOS 27.1, *)
private struct SplitAxisReader<Content: View>: View {
  @Environment(\.splitArrangementAxis) private var axis
  @ViewBuilder let content: (Axis?) -> Content

  var body: some View {
    content(axis)
  }
}
