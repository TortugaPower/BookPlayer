//
//  AudiobookShelfLibraryListView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/14/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct AudiobookShelfLibraryListView<Model: AudiobookShelfLibraryViewModelProtocol>: View {
  @ObservedObject var viewModel: Model

  var body: some View {
    List(viewModel.items, selection: $viewModel.selectedItems) { item in
      row(item: item)
        .selectionDisabled(item.kind != .audiobook)
    }
  }

  func row(item: AudiobookShelfLibraryItem) -> some View {
    AudiobookShelfLibraryListItemView(item: item)
      .accessibilityAddTraits(.isButton)
      .contentShape(Rectangle())
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
      .id("\(item.id)-\(viewModel.selectedItems.contains(item.id))")
  }
}
