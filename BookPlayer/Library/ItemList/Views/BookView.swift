//
//  BookView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Kingfisher
import SwiftUI

struct BookView: View {
  let item: SimpleLibraryItem
  let artworkTap: () -> Void

  @Environment(\.syncService) private var syncService
  @Environment(\.playingItemParentPath) private var playingItemParentPath
  @Environment(\.playerState) private var playerState
  @Environment(\.listState) private var listState
  @EnvironmentObject private var theme: ThemeViewModel

  var isHighlighted: Bool {
    playerState.loadedBookRelativePath == item.relativePath || playingItemParentPath == item.relativePath
  }

  var titleColor: Color {
    isHighlighted
      ? theme.linkColor
      : theme.primaryColor
  }

  var body: some View {
    HStack(spacing: 0) {
      Button(action: artworkTap) {
        ItemArtworkView(
          item: item,
          isHighlighted: isHighlighted,
          syncService: syncService
        )
      }
      .buttonStyle(.plain)
      VStack(alignment: .leading) {
        Text(verbatim: item.title)
          .font(.subheadline)
          .fontWeight(.bold)
          .foregroundStyle(titleColor)
        Text(verbatim: item.details)
          .foregroundStyle(theme.secondaryColor)
          .font(.caption)
        Text(verbatim: item.durationFormatted)
          .foregroundStyle(theme.secondaryColor)
          .font(.caption)
      }
      .padding(.leading, Spacing.S)
      Spacer()
      if !listState.isEditing {
        ItemProgressView(
          item: item,
          isHighlighted: isHighlighted
        )
      }
    }
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
    .accessibilityLabel(VoiceOverService.getAccessibilityLabel(for: item))
  }
}

#Preview {
  @Previewable var syncService: SyncService = {
    let syncService = SyncService()
    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: ""))
    let libraryService = LibraryService()
    libraryService.setup(dataManager: dataManager)
    syncService.setup(
      isActive: true,
      libraryService: libraryService
    )

    return syncService
  }()

  BookView(
    item: .init(
      title: "Test",
      details: "Details",
      speed: 1,
      currentTime: 0,
      duration: 0,
      percentCompleted: 78,
      isFinished: false,
      relativePath: "",
      remoteURL: nil,
      artworkURL: nil,
      orderRank: 0,
      parentFolder: nil,
      originalFileName: "",
      lastPlayDate: nil,
      type: .book
    )
  ) {}
  .environment(\.syncService, syncService)
  .environmentObject(ThemeViewModel())
}
