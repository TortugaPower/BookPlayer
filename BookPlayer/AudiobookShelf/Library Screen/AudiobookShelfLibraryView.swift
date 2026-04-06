//
//  AudiobookShelfLibraryView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/14/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI

/// Thin wrapper providing AudiobookShelf-specific cell, row, sort picker, and environment
/// to the shared `IntegrationLibraryView`.
struct AudiobookShelfLibraryView<Model: IntegrationLibraryViewModelProtocol>: View
where Model.Item == AudiobookShelfLibraryItem {
  @ObservedObject var viewModel: Model

  var body: some View {
    IntegrationLibraryView(
      viewModel: viewModel,
      gridCell: { item in
        AudiobookShelfLibraryGridItemView(
          item: item,
          isSelected: viewModel.selectedItems.contains(item.id)
        )
      },
      listRow: { item in
        AudiobookShelfLibraryListItemView(item: item)
      },
      sortPicker: {
        sortPickerContent
      }
    )
    .environment(\.audiobookshelfService, (viewModel as? AudiobookShelfLibraryViewModel)?.connectionService ?? .init())
  }

  @ViewBuilder
  private var sortPickerContent: some View {
    if let vm = viewModel as? AudiobookShelfLibraryViewModel {
      Picker(selection: Binding(
        get: { vm.sortBy },
        set: { vm.sortBy = $0 }
      ), label: Text("Sort by".localized)) {
        Label("sort_most_recent_button", systemImage: "clock").tag(AudiobookShelfLayout.SortBy.recent)
        Label("Title".localized, systemImage: "textformat.abc").tag(AudiobookShelfLayout.SortBy.title)
      }
    }
  }
}
