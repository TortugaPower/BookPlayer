//
//  AudiobookShelfLibraryGridView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/14/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct AudiobookShelfLibraryGridView<Model: AudiobookShelfLibraryViewModelProtocol>: View {
  @ObservedObject var viewModel: Model

  @ScaledMetric var accessabilityScale: CGFloat = 1
  @State private var availableSize: CGSize = .zero
  private let itemMinSizeBase = CGSize(width: 100, height: 100)
  private let itemMaxSizeBase = CGSize(width: 250, height: 250)
  private let itemSpacingBase = 20.0

  private func adjustSize(_ size: CGSize, availableSize: CGSize) -> CGSize {
    CGSize(
      width: min(size.width, availableSize.width),
      height: min(size.height * accessabilityScale, availableSize.height)
    )
  }

  var body: some View {
    GeometryReader { geometry in
      AdaptiveVGrid(
        numItems: viewModel.items.count,
        itemMinSize: adjustSize(itemMinSizeBase, availableSize: geometry.size),
        itemMaxSize: adjustSize(itemMaxSizeBase, availableSize: geometry.size),
        itemSpacing: itemSpacingBase * accessabilityScale
      ) {
        ForEach(viewModel.items, id: \.id) { item in
          AudiobookShelfLibraryGridItemView(item: item, isSelected: viewModel.selectedItems.contains(item.id))
            .accessibilityAddTraits(.isButton)
            .onTapGesture {
              if viewModel.editMode.isEditing {
                guard case .audiobook = item.kind else { return }
                viewModel.onSelectTapped(for: item)
              } else {
                switch item.kind {
                case .audiobook, .podcast:
                  viewModel.navigation.path.append(AudiobookShelfLibraryLevelData.details(data: item))
                case .library:
                  viewModel.navigation.path.append(AudiobookShelfLibraryLevelData.library(data: item))
                }
              }
            }
            .onAppear {
              viewModel.fetchMoreItemsIfNeeded(currentItem: item)
            }
            .frame(
              minWidth: adjustSize(itemMinSizeBase, availableSize: geometry.size).width,
              maxWidth: CGFloat.greatestFiniteMagnitude,
              minHeight: adjustSize(itemMinSizeBase, availableSize: geometry.size).height,
              maxHeight: adjustSize(itemMaxSizeBase, availableSize: geometry.size).height
            )
        }
      }
    }
  }
}

final class MockAudiobookShelfLibraryViewModel: AudiobookShelfLibraryViewModelProtocol, ObservableObject {
  var navigationTitle: String = ""
  var navigation = BPNavigation()
  var connectionService = AudiobookShelfConnectionService()

  let data: AudiobookShelfLibraryLevelData

  var layout = AudiobookShelfLayout.Options.grid
  var sortBy = AudiobookShelfLayout.SortBy.recent

  @Published var items: [AudiobookShelfLibraryItem] = []
  var totalItems: Int { items.count }
  var error: Error?

  var editMode: EditMode = .inactive
  var selectedItems: Set<AudiobookShelfLibraryItem.ID> = []

  init(data: AudiobookShelfLibraryLevelData) {
    self.data = data
  }

  func fetchInitialItems() {}
  func fetchMoreItemsIfNeeded(currentItem: AudiobookShelfLibraryItem) {}
  func cancelFetchItems() {}

  func handleDoneAction() {}

  func onEditToggleSelectTapped() {}
  func onSelectTapped(for item: AudiobookShelfLibraryItem) {}
  func onSelectAllTapped() {}
  func onDownloadTapped() {}
}

#Preview("top level") {
  let model = {
    let model = MockAudiobookShelfLibraryViewModel(data: .topLevel(libraryName: "Mock Library"))
    model.items = [
      AudiobookShelfLibraryItem(
        id: "0.1",
        title: "The Great Gatsby",
        kind: .audiobook,
        libraryId: "1"
      ),
      AudiobookShelfLibraryItem(
        id: "0.2",
        title: "To Kill a Mockingbird",
        kind: .audiobook,
        libraryId: "2"
      ),
      AudiobookShelfLibraryItem(
        id: "0.3",
        title: "A Very Long Book Title That Should Wrap to Multiple Lines",
        kind: .audiobook,
        libraryId: "3"
      ),
      AudiobookShelfLibraryItem(
        id: "0.4",
        title: "1984",
        kind: .audiobook,
        libraryId: "4"
      ),
      AudiobookShelfLibraryItem(
        id: "0.5",
        title: "Pride and Prejudice",
        kind: .audiobook,
        libraryId: "5"
      )
    ]
    return model
  }()
  AudiobookShelfLibraryGridView(viewModel: model)
    .environmentObject(ThemeViewModel())
}
