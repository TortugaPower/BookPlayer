//
//  AudiobookShelfLibraryView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/14/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Kingfisher
import SwiftUI

struct AudiobookShelfLibraryView<Model: AudiobookShelfLibraryViewModelProtocol>: View {
  @StateObject var viewModel: Model
  @EnvironmentObject private var theme: ThemeViewModel

  var navigationTitle: Text {
    if viewModel.editMode.isEditing, !viewModel.selectedItems.isEmpty {
      return Text(
        String(format: "audiobookshelf_selection_count".localized, viewModel.selectedItems.count, viewModel.totalItems)
      )
    } else {
      return Text(viewModel.navigationTitle)
    }
  }

  var body: some View {
    Group {
      if viewModel.layout == .grid {
        AudiobookShelfLibraryGridView(viewModel: viewModel)
          .padding()
      } else {
        AudiobookShelfLibraryListView(viewModel: viewModel)
      }
    }
    .environment(\.audiobookshelfService, viewModel.connectionService)
    .onAppear { viewModel.fetchInitialItems() }
    .onDisappear { viewModel.cancelFetchItems() }
    .errorAlert(error: $viewModel.error)
    .environment(\.editMode, $viewModel.editMode)
    .toolbar {
      ToolbarItem(placement: .principal) {
        navigationTitle
          .font(.headline)
          .foregroundStyle(theme.primaryColor)
      }
      ToolbarItemGroup(placement: .topBarTrailing) {
        toolbarTrailing
      }
    }
    .toolbar {
      if viewModel.editMode.isEditing {
        ToolbarItemGroup(placement: .bottomBar) {
          bottomBar
        }
      }
    }
  }

  @ViewBuilder
  var toolbarTrailing: some View {
    if !viewModel.editMode.isEditing {
      Menu {
        Section {
          Button(action: viewModel.onEditToggleSelectTapped) {
            Label("select_title".localized, systemImage: "checkmark.circle")
          }
        }

        layoutPreferences
      } label: {
        Label("more_title".localized, systemImage: "ellipsis.circle")
      }
    } else {
      Button(action: viewModel.onEditToggleSelectTapped) {
        Text("done_title".localized).bold()
      }
    }
  }

  @ViewBuilder
  var layoutPreferences: some View {
    Section {
      Picker(selection: $viewModel.layout, label: Text("Layout options".localized)) {
        Label("Grid".localized, systemImage: "square.grid.2x2").tag(AudiobookShelfLayout.Options.grid)
        Label("List".localized, systemImage: "list.bullet").tag(AudiobookShelfLayout.Options.list)
      }
    }
    Section {
      Picker(selection: $viewModel.sortBy, label: Text("Sort by".localized)) {
        Text("Recently Added".localized).tag(AudiobookShelfLayout.SortBy.recent)
        Label("Title".localized, systemImage: "textformat.abc").tag(AudiobookShelfLayout.SortBy.title)
      }
    }
  }

  @ViewBuilder
  var bottomBar: some View {
    Button(action: viewModel.onSelectAllTapped) {
      Image(systemName: viewModel.selectedItems.isEmpty ? "checklist.checked" : "checklist.unchecked")
    }

    Spacer()

    Button(action: viewModel.onDownloadTapped) {
      Image(systemName: "arrow.down.to.line")
    }
    .disabled(viewModel.selectedItems.isEmpty)
  }
}
