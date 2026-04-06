//
//  JellyfinLibraryView.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-10-27.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import SwiftUI

/// Thin wrapper providing Jellyfin-specific cell, row, sort picker, and environment
/// to the shared `IntegrationLibraryView`.
struct JellyfinLibraryView<Model: IntegrationLibraryViewModelProtocol>: View
where Model.Item == JellyfinLibraryItem {
  @StateObject var viewModel: Model

  var body: some View {
    IntegrationLibraryView(
      viewModel: viewModel,
      gridCell: { item in
        JellyfinLibraryGridItemView(
          item: item,
          isSelected: viewModel.selectedItems.contains(item.id)
        )
      },
      listRow: { item in
        JellyfinLibraryListItemView(item: item)
      },
      sortPicker: {
        sortPickerContent
      }
    )
    .environment(\.jellyfinService, jellyfinConnectionService)
  }

  private var jellyfinConnectionService: JellyfinConnectionService {
    (viewModel as? JellyfinLibraryViewModel)?.connectionService
      ?? (viewModel as? JellyfinAuthorBooksViewModel)?.connectionService
      ?? (viewModel as? JellyfinNarratorBooksViewModel)?.connectionService
      ?? (viewModel as? JellyfinAuthorsListViewModel)?.connectionService
      ?? (viewModel as? JellyfinNarratorsListViewModel)?.connectionService
      ?? .init()
  }

  @ViewBuilder
  private var sortPickerContent: some View {
    if let vm = viewModel as? JellyfinLibraryViewModel {
      Picker(selection: Binding(
        get: { vm.sortBy },
        set: { vm.sortBy = $0 }
      ), label: Text("Sort by".localized)) {
        Text("Default".localized).tag(JellyfinLayout.SortBy.smart)
        Label("sort_most_recent_button", systemImage: "clock").tag(JellyfinLayout.SortBy.recent)
        Label("Name".localized, systemImage: "textformat.abc").tag(JellyfinLayout.SortBy.name)
      }
    }
  }
}
