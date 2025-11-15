//
//  ItemListView+Sheets.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/10/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

// MARK: - Sheet Content Builders
extension ItemListView {
  @ViewBuilder
  func sheetContent(for sheet: ItemListSheet) -> some View {
    switch sheet {
    case .itemDetails(let item):
      itemDetailsSheet(for: item)
    case .queuedTasks:
      QueuedSyncTasksView()
    case .jellyfin:
      JellyfinRootView(connectionService: jellyfinService)
    case .audiobookshelf:
      AudiobookShelfRootView(connectionService: audiobookshelfService)
    case .foldersSelection:
      foldersSelectionSheet()
    }
  }
  
  @ViewBuilder
  private func itemDetailsSheet(for item: SimpleLibraryItem) -> some View {
    NavigationStack {
      ItemDetailsView {
        ItemDetailsViewModel(
          item: item,
          libraryService: libraryService,
          syncService: syncService,
          hardcoverService: hardcoverService,
          listState: listState
        )
      }
    }
  }
  
  @ViewBuilder
  private func foldersSelectionSheet() -> some View {
    ItemListSelectionView(items: model.getAvailableFolders()) { folder in
      model.handleMoveIntoFolder(folder)
    }
  }
}
