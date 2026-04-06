//
//  JellyfinLibraryGridView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/6/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct JellyfinLibraryGridView<Model: JellyfinLibraryViewModelProtocol>: View {
  @ObservedObject var viewModel: Model

  @ScaledMetric var accessabilityScale: CGFloat = 1
  @State private var availableSize: CGSize = .zero
  private let itemMinSizeBase = CGSize(width: 100, height: 100)
  private let itemMaxSizeBase = CGSize(width: 250, height: 250)
  private let itemSpacingBase = 20.0

  private var columns: [GridItem] {
    [GridItem(
      .adaptive(
        minimum: itemMinSizeBase.width,
        maximum: itemMaxSizeBase.width
      ),
      spacing: itemSpacingBase * accessabilityScale
    )]
  }

  var body: some View {
    LazyVGrid(columns: columns, spacing: itemSpacingBase * accessabilityScale) {
      ForEach(viewModel.items, id: \.id) { item in
        JellyfinLibraryGridItemView(item: item, isSelected: viewModel.selectedItems.contains(item.id))
          .accessibilityAddTraits(.isButton)
          .onTapGesture {
            if viewModel.editMode.isEditing {
              guard item.isDownloadable else { return }
              viewModel.onSelectTapped(for: item)
            } else if let destination = viewModel.destination(for: item) {
              viewModel.navigation.path.append(destination)
            }
          }
          .onAppear {
            viewModel.fetchMoreItemsIfNeeded(currentItem: item)
          }
      }
    }
  }
}

final class MockJellyfinLibraryViewModel: JellyfinLibraryViewModelProtocol, ObservableObject {
  var navigationTitle: String = ""
  var navigation = BPNavigation()
  var connectionService = JellyfinConnectionService()

  let data: JellyfinLibraryLevelData

  var searchQuery: String = ""
  var isSearchable: Bool { false }

  var layout = JellyfinLayout.Options.grid
  var sortBy = JellyfinLayout.SortBy.smart

  @Published var items: [JellyfinLibraryItem] = []
  var totalItems: Int { items.count }
  var error: Error?

  var editMode: EditMode = .inactive
  var selectedItems: Set<JellyfinLibraryItem.ID> = []
  var downloadRemaining: Int = 0
  var showingDownloadConfirmation: Bool = false

  init(data: JellyfinLibraryLevelData) {
    self.data = data
  }

  func fetchInitialItems() {}
  func fetchMoreItemsIfNeeded(currentItem: JellyfinLibraryItem) {}
  func cancelFetchItems() {}
  func destination(for item: JellyfinLibraryItem) -> JellyfinLibraryLevelData? { nil }

  func handleDoneAction() {}

  func onEditToggleSelectTapped() {}
  func onSelectTapped(for item: JellyfinLibraryItem) {}
  func onSelectAllTapped() {}
  func onDownloadTapped() {}
  func onDownloadFolderTapped() {}
  func confirmDownloadFolder() {}
}

#Preview("top level") {
  let model = {
    let model = MockJellyfinLibraryViewModel(data: .topLevel(libraryName: "Mock Library"))
    model.items = [
      JellyfinLibraryItem(id: "0.0", name: "subfolder", kind: .folder),
      JellyfinLibraryItem(id: "0.1", name: "book", kind: .audiobook),
      JellyfinLibraryItem(id: "0.2", name: "another book", kind: .audiobook),
      JellyfinLibraryItem(id: "0.3", name: "subfolder 2", kind: .folder),
      JellyfinLibraryItem(
        id: "0.4",
        name: "book 2 with a very very very very very long name\nmaybe even a line break?",
        kind: .audiobook
      ),
      JellyfinLibraryItem(id: "0.5", name: "another book 2", kind: .audiobook),
      JellyfinLibraryItem(id: "0.6", name: "subfolder 3", kind: .folder),
      JellyfinLibraryItem(id: "0.7", name: "book 3", kind: .audiobook),
      JellyfinLibraryItem(id: "0.8", name: "another book 3", kind: .audiobook),
      JellyfinLibraryItem(id: "0.9", name: "subfolder 2", kind: .folder),
      JellyfinLibraryItem(id: "0.10", name: "book 2", kind: .audiobook),
      JellyfinLibraryItem(id: "0.11", name: "another book 2", kind: .audiobook),
      JellyfinLibraryItem(id: "0.12", name: "subfolder 3", kind: .folder),
      JellyfinLibraryItem(id: "0.13", name: "book 3", kind: .audiobook),
      JellyfinLibraryItem(id: "0.14", name: "another book 3", kind: .audiobook),
      JellyfinLibraryItem(id: "0.15", name: "subfolder 2", kind: .folder),
      JellyfinLibraryItem(id: "0.16", name: "book 2", kind: .audiobook),
      JellyfinLibraryItem(id: "0.17", name: "another book 2", kind: .audiobook),
      JellyfinLibraryItem(id: "0.18", name: "subfolder 3", kind: .folder),
      JellyfinLibraryItem(id: "0.19", name: "book 3", kind: .audiobook),
      JellyfinLibraryItem(id: "0.20", name: "another book 3", kind: .audiobook),
    ]
    return model
  }()
  JellyfinLibraryView(viewModel: model)
}

#Preview("folder") {
  let model = {
    let topLevelFolder = JellyfinLibraryItem(id: "0", name: "some folder", kind: .folder)
    let model = MockJellyfinLibraryViewModel(data: .folder(data: topLevelFolder))
    model.items = [
      JellyfinLibraryItem(id: "0.0", name: "subfolder", kind: .folder),
      JellyfinLibraryItem(id: "0.1", name: "book", kind: .audiobook),
      JellyfinLibraryItem(id: "0.2", name: "another book", kind: .audiobook),
      JellyfinLibraryItem(id: "0.3", name: "subfolder 2", kind: .folder),
      JellyfinLibraryItem(
        id: "0.4",
        name: "book 2 with a very very long name\nmaybe even a line break?",
        kind: .audiobook
      ),
      JellyfinLibraryItem(id: "0.5", name: "another book 2", kind: .audiobook),
      JellyfinLibraryItem(id: "0.6", name: "subfolder 3", kind: .folder),
      JellyfinLibraryItem(id: "0.7", name: "book 3", kind: .audiobook),
      JellyfinLibraryItem(id: "0.8", name: "another book 3", kind: .audiobook),
      JellyfinLibraryItem(id: "0.9", name: "subfolder 2", kind: .folder),
      JellyfinLibraryItem(id: "0.10", name: "book 2", kind: .audiobook),
      JellyfinLibraryItem(id: "0.11", name: "another book 2", kind: .audiobook),
      JellyfinLibraryItem(id: "0.12", name: "subfolder 3", kind: .folder),
      JellyfinLibraryItem(id: "0.13", name: "book 3", kind: .audiobook),
      JellyfinLibraryItem(id: "0.14", name: "another book 3", kind: .audiobook),
      JellyfinLibraryItem(id: "0.15", name: "subfolder 2", kind: .folder),
      JellyfinLibraryItem(id: "0.16", name: "book 2", kind: .audiobook),
      JellyfinLibraryItem(id: "0.17", name: "another book 2", kind: .audiobook),
      JellyfinLibraryItem(id: "0.18", name: "subfolder 3", kind: .folder),
      JellyfinLibraryItem(id: "0.19", name: "book 3", kind: .audiobook),
      JellyfinLibraryItem(id: "0.20", name: "another book 3", kind: .audiobook),
    ]
    return model
  }()
  JellyfinLibraryView(viewModel: model)
}
