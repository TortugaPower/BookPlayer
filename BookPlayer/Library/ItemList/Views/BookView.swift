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

  /// Set from `LibraryOptionsView`. When true (and the item has one), the row
  /// shows the imported file name instead of the parsed title.
  @AppStorage(
    wrappedValue: false,
    Constants.UserDefaults.libraryDisplayTitleSource,
    store: UserDefaults(suiteName: Constants.ApplicationGroupIdentifier)
  )
  private var useOriginalFileName: Bool

  private var displayTitle: String {
    item.displayTitle(useOriginalFileName: useOriginalFileName)
  }

  var isHighlighted: Bool {
    playerState.loadedBookRelativePath == item.relativePath || playingItemParentPath == item.relativePath
  }

  var titleColor: Color {
    isHighlighted
      ? theme.linkColor
      : theme.primaryColor
  }

  /// Provider glyphs then the author, as ONE `Text` rather than a stack of them.
  ///
  /// Concatenation buys three things a stack can't: an interpolated `Image` is sized from the
  /// font, so the provider icon grows with Dynamic Type instead of sitting at a fixed 12pt;
  /// the enclosing VStack keeps its font-derived default spacing, which SwiftUI applies only
  /// between adjacent `Text` views (an `HStack` child forfeits it, and needed a hardcoded gap
  /// to look right); and the subtitle truncates once at the end instead of each piece
  /// competing for width and truncating on its own.
  ///
  /// The font sizing holds only because the provider icons are symbol sets: a plain image set
  /// interpolated into `Text` draws at its intrinsic point size with its bottom edge pinned to
  /// the baseline, which is how these read as oversized and misaligned before. Keep them as
  /// `.symbolset`s drawn to the cap-height guides, or this comment stops being true.
  ///
  /// The row is a single accessibility element (`children: .ignore` +
  /// `dynamicAccessibilityLabel`), so nothing here reaches VoiceOver and the glyphs need no
  /// `accessibilityHidden`. They are also the only visible trace of where the item came from,
  /// which is why `VoiceOverService` takes `includeSource` and speaks the provider names.
  private var subtitle: Text {
    // Media-server links only, same rule the details section uses: Hardcover is
    // progress-sync, not a source the book streams from, so it earns no badge here.
    (item.externalResources?.displayOrderedMediaServerResources ?? [])
      .compactMap(\.mediaServer)
      .reduce(Text(verbatim: "")) { partial, provider in
        // Glyph only: the provider name next to its own logo was a second copy of the same
        // fact, and it crowded the author off the one line this row gives it.
        partial + Text("\(Image(provider.icon)) ")
      }
      // Appended outside the reduce: the author renders even when the item has no external
      // resources (nil for locally-imported books on some construction paths).
      + Text(verbatim: item.details)
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
      .accessibilityLabel("voiceover_continue_playback_title")
      VStack(alignment: .leading) {
        Text(verbatim: displayTitle)
          .bpFont(.subheadline)
          .fontWeight(.bold)
          .foregroundStyle(titleColor)
        subtitle
          .foregroundStyle(theme.secondaryColor)
          .bpFont(.caption)
        Text(verbatim: item.durationFormatted)
          .foregroundStyle(theme.secondaryColor)
          .bpFont(.caption)
      }
      .padding(.leading, Spacing.S)
      Spacer()
      ItemProgressView(
        item: item,
        isHighlighted: isHighlighted
      )
    }
    .contentShape(Rectangle())
    .accessibilityElement(children: .ignore)
    .dynamicAccessibilityLabel(for: item)
  }
}

#Preview {
  @Previewable var syncService: SyncService = {
    let syncService = SyncService()
    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: ""))
    let audioMetadataService = AudioMetadataService()
    let libraryService = LibraryService()
    libraryService.setup(dataManager: dataManager, audioMetadataService: audioMetadataService)
    let accountService = AccountService()
    accountService.setup(dataManager: dataManager)
    let tasksDataManager = TasksDataManager()
    let syncQueueService = SyncQueueService()
    syncQueueService.setup(
      libraryService: libraryService,
      getAccessLevel: { accountService.getAccessLevel() },
      tasksDataManager: tasksDataManager,
      networkClient: NetworkClient(),
      dataManager: dataManager
    )
    syncService.setup(
      isActive: true,
      libraryService: libraryService,
      accountService: accountService,
      syncQueueService: syncQueueService
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
      type: .book,
      uuid: UUID().uuidString
    )
  ) {}
  .environment(\.syncService, syncService)
  .environmentObject(ThemeViewModel())
}
