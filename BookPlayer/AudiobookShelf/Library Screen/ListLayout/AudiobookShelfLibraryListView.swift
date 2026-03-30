//
//  AudiobookShelfLibraryListView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/14/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct AudiobookShelfLibraryListView<Model: AudiobookShelfLibraryViewModelProtocol>: View {
  @ObservedObject var viewModel: Model
  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    List(viewModel.items, selection: $viewModel.selectedItems) { item in
      row(item: item)
        .selectionDisabled(!item.isDownloadable)
        .listRowBackground(theme.tertiarySystemBackgroundColor)
    }
  }

  func row(item: AudiobookShelfLibraryItem) -> some View {
    AudiobookShelfLibraryListItemView(item: item)
      .accessibilityAddTraits(.isButton)
      .contentShape(Rectangle())
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
      .id("\(item.id)-\(viewModel.selectedItems.contains(item.id))")
  }
}
