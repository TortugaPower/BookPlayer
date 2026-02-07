//
//  JellyfinLibraryListView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 9/6/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct JellyfinLibraryListView<Model: JellyfinLibraryViewModelProtocol>: View {
  @ObservedObject var viewModel: Model
  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    List(viewModel.items, selection: $viewModel.selectedItems) { item in
      row(item: item)
        .selectionDisabled(item.kind != .audiobook)
        .listRowBackground(theme.tertiarySystemBackgroundColor)
    }
  }

  func row(item: JellyfinLibraryItem) -> some View {
    JellyfinLibraryListItemView(item: item)
      .accessibilityAddTraits(.isButton)
      .contentShape(Rectangle())
      .onTapGesture {
        if viewModel.editMode.isEditing {
          guard case .audiobook = item.kind else { return }
          viewModel.onSelectTapped(for: item)
        } else {
          switch item.kind {
          case .audiobook:
            viewModel.navigation.path.append(JellyfinLibraryLevelData.details(data: item))
          case .userView, .folder:
            viewModel.navigation.path.append(JellyfinLibraryLevelData.folder(data: item))
          }
        }
      }
      .onAppear {
        viewModel.fetchMoreItemsIfNeeded(currentItem: item)
      }
      .id("\(item.id)-\(viewModel.selectedItems.contains(item.id))")
  }
}
