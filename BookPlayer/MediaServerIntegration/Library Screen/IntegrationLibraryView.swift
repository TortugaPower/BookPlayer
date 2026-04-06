//
//  IntegrationLibraryView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/5/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct IntegrationLibraryView<
  Model: IntegrationLibraryViewModelProtocol,
  GridCell: View,
  ListRow: View,
  SortPicker: View
>: View {
  @ObservedObject var viewModel: Model
  @ViewBuilder let gridCell: (Model.Item) -> GridCell
  @ViewBuilder let listRow: (Model.Item) -> ListRow
  @ViewBuilder let sortPicker: () -> SortPicker

  @EnvironmentObject private var theme: ThemeViewModel
  @Environment(\.tabEditing) private var tabEditing

  var navigationTitle: Text {
    if viewModel.editMode.isEditing, !viewModel.selectedItems.isEmpty {
      return Text(
        String(format: "integration_selection_count".localized, viewModel.selectedItems.count, viewModel.totalItems)
      )
    } else {
      return Text(viewModel.navigationTitle)
    }
  }

  var body: some View {
    Group {
      if viewModel.isGridEnabled, viewModel.layout == .grid {
        ScrollView {
          IntegrationLibraryGridView(viewModel: viewModel, cellContent: gridCell)
            .padding()
        }
      } else {
        IntegrationLibraryListView(viewModel: viewModel, rowContent: listRow)
          .scrollContentBackground(.hidden)
      }
    }
    .scrollDismissesKeyboard(.interactively)
    .background(theme.systemBackgroundColor)
    .modifier(IntegrationSearchableModifier(
      isSearchable: viewModel.isSearchable,
      text: $viewModel.searchQuery
    ))
    .searchPresentationToolbarBehavior(.avoidHidingContent)
    .onAppear { viewModel.fetchInitialItems() }
    .onDisappear { viewModel.cancelFetchItems() }
    .errorAlert(error: $viewModel.error)
    .environment(\.editMode, $viewModel.editMode)
    .onChange(of: viewModel.editMode) { _, newValue in
      tabEditing.wrappedValue = newValue.isEditing
    }
    .confirmationDialog(
      "download_folder_confirmation_title".localized,
      isPresented: $viewModel.showingDownloadConfirmation
    ) {
      Button("download_title".localized) {
        viewModel.confirmDownloadFolder()
      }
      Button("cancel_button".localized, role: .cancel) {}
    } message: {
      Text(String.localizedStringWithFormat("download_folder_confirmation_message".localized, viewModel.totalItems))
    }
    .toolbar {
      ToolbarItem(placement: .principal) {
        navigationTitle
          .bpFont(.headline)
          .foregroundStyle(theme.primaryColor)
      }
      ToolbarItemGroup(placement: .topBarTrailing) {
        toolbarTrailing
      }
    }
    .toolbar {
      if viewModel.allowsEditing, viewModel.editMode.isEditing {
        ToolbarItemGroup(placement: .bottomBar) {
          bottomBar
        }
      }
    }
  }

  @ViewBuilder
  var toolbarTrailing: some View {
    if !viewModel.editMode.isEditing,
       viewModel.allowsEditing || viewModel.showsLayoutPreferences || viewModel.showsSortPreferences {
      Menu {
        if viewModel.allowsEditing {
          ThemedSection {
            Button(action: viewModel.onEditToggleSelectTapped) {
              Label("select_title".localized, systemImage: "checkmark.circle")
            }
            Button(action: viewModel.onDownloadFolderTapped) {
              Label("download_title".localized, systemImage: "arrow.down.to.line")
            }
          }
        }

        layoutPreferences
      } label: {
        Label("more_title".localized, systemImage: "ellipsis.circle")
      }
    } else if viewModel.allowsEditing {
      Button(action: viewModel.onEditToggleSelectTapped) {
        Text("done_title".localized).bold()
      }
    }
  }

  @ViewBuilder
  var layoutPreferences: some View {
    if viewModel.showsLayoutPreferences {
      ThemedSection {
        Picker(selection: $viewModel.layout, label: Text("Layout options".localized)) {
          Label("Grid".localized, systemImage: "square.grid.2x2").tag(IntegrationLayout.Options.grid)
          Label("List".localized, systemImage: "list.bullet").tag(IntegrationLayout.Options.list)
        }
      }
    }
    if viewModel.showsSortPreferences {
      ThemedSection {
        sortPicker()
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

// MARK: - Searchable Modifier

struct IntegrationSearchableModifier: ViewModifier {
  let isSearchable: Bool
  @Binding var text: String

  func body(content: Content) -> some View {
    if isSearchable {
      content.searchable(text: $text, placement: .navigationBarDrawer(displayMode: .always))
    } else {
      content
    }
  }
}
