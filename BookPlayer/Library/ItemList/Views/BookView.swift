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

  /// Provider links then the author, as ONE `Text` rather than a stack of them.
  ///
  /// Concatenation buys three things a stack can't: an interpolated `Image` is sized from the
  /// font, so the provider icon grows with Dynamic Type instead of sitting at a fixed 12pt;
  /// the enclosing VStack keeps its font-derived default spacing, which SwiftUI applies only
  /// between adjacent `Text` views (an `HStack` child forfeits it, and needed a hardcoded gap
  /// to look right); and the subtitle truncates once at the end instead of each piece
  /// competing for width and truncating on its own.
  ///
  /// The row is a single accessibility element (`children: .ignore` +
  /// `dynamicAccessibilityLabel`), so nothing here reaches VoiceOver — the icon and the
  /// separator need no `accessibilityHidden`.
  private var subtitle: Text {
    (item.externalResources ?? [])
      .reduce(Text(verbatim: "")) { partial, resource in
        let provider = ExternalResource.ProviderName(rawValue: resource.providerName) ?? .jellyfin

        return partial + Text("\(Image(provider.icon)) \(resource.providerName.capitalized) • ")
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
    let concurrenceService = ConcurrenceService()
    concurrenceService.setup(
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
      concurrenceService: concurrenceService,
      tasksDataManager: tasksDataManager
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
