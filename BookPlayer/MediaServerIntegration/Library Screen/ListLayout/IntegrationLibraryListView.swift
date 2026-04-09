//
//  IntegrationLibraryListView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/5/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct IntegrationLibraryListView<
  Model: IntegrationLibraryViewModelProtocol,
  RowContent: View
>: View {
  @ObservedObject var viewModel: Model
  @ViewBuilder let rowContent: (Model.Item) -> RowContent

  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    List(viewModel.items, selection: $viewModel.selectedItems) { item in
      row(item: item)
        .selectionDisabled(!item.isDownloadable)
        .listRowBackground(theme.tertiarySystemBackgroundColor)
    }
  }

  func row(item: Model.Item) -> some View {
    rowContent(item)
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
  }
}
