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
    case .foldersSelection:
      foldersSelectionSheet()
    case .libraryOptions:
      libraryOptionsSheet()
    }
  }

  @ViewBuilder
  private func libraryOptionsSheet() -> some View {
    let location = currentLocation
    LibraryOptionsView(
      location: location,
      canApplyStickySort: canApplyStickySort,
      onSelectionChange: { effective in
        switch effective {
        case .automatic(let sort):
          // Goes through `sortContents` which rewrites ranks and writes the pref via Hook 1.
          model.handleSort(by: sort)
        case .custom:
          // No drag happened — just flip the pref. orderRanks stay where they are; from now
          // on, sync will push rank changes since the location is no longer auto-sorted.
          preferencesService?.setSort(.custom, forLocation: location)
        }
      }
    )
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
