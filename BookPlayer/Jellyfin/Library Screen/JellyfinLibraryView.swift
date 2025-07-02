//
//  JellyfinLibraryView.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-10-27.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Kingfisher
import SwiftUI

struct JellyfinLibraryView<Model: JellyfinLibraryViewModelProtocol>: View {
  @StateObject var viewModel: Model
  @StateObject private var themeViewModel = ThemeViewModel()

  var navigationTitle: Text {
    if viewModel.editMode.isEditing, !viewModel.selectedItems.isEmpty {
      return Text("\(viewModel.selectedItems.count) of \(viewModel.totalItems) Items")
    } else {
      return Text(viewModel.navigationTitle)
    }
  }

  var body: some View {
    Group {
      if viewModel.layout == .grid {
        JellyfinLibraryGridView(viewModel: viewModel)
          .padding()
      } else {
        JellyfinLibraryListView(viewModel: viewModel)
      }
    }
    .environmentObject(themeViewModel)
    .environmentObject(viewModel.connectionService)
    .onAppear { viewModel.fetchInitialItems() }
    .onDisappear { viewModel.cancelFetchItems() }
    .errorAlert(error: $viewModel.error)
    .environment(\.editMode, $viewModel.editMode)
    .confirmationDialog(
      "download_folder_confirmation_title".localized,
      isPresented: $viewModel.showingDownloadConfirmation
    ) {
      Button("download_folder_confirm_button".localized) {
        viewModel.confirmDownloadFolder()
      }
      Button("cancel_button".localized, role: .cancel) { }
    } message: {
      Text(String.localizedStringWithFormat("download_folder_confirmation_message".localized, viewModel.totalItems))
    }
    .toolbar {
      ToolbarItem(placement: .principal) {
        navigationTitle
          .font(.headline)
          .foregroundColor(themeViewModel.primaryColor)
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
          if #available(iOS 17.0, *) {
            Button(action: viewModel.onEditToggleSelectTapped) {
              Label("Select".localized, systemImage: "checkmark.circle")
            }
          }
          Button(action: viewModel.onDownloadFolderTapped) {
            Label("Download".localized, systemImage: "arrow.down.to.line")
          }
        }

        layoutPreferences
      } label: {
        Label("more_title".localized, systemImage: "ellipsis.circle")
      }
    } else {
      Button(action: viewModel.onEditToggleSelectTapped) {
        Text("Done".localized).bold()
      }
    }
  }

  @ViewBuilder
  var layoutPreferences: some View {
    Section {
      Picker(selection: $viewModel.layout, label: Text("Layout options".localized)) {
        Label("Grid".localized, systemImage: "square.grid.2x2").tag(JellyfinLayout.Options.grid)
        Label("List".localized, systemImage: "list.bullet").tag(JellyfinLayout.Options.list)
      }
    }
    Section {
      Picker(selection: $viewModel.sortBy, label: Text("Sort by".localized)) {
        Text("Default".localized).tag(JellyfinLayout.SortBy.smart)
        Label("Name".localized, systemImage: "textformat.abc").tag(JellyfinLayout.SortBy.name)
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
