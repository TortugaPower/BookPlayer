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
    .sheet(item: $viewModel.pendingImportBatch) { batch in
      ExternalImportView(
        initModel: {
          ExternalImportViewModel(batch: batch) { resources in
            viewModel.confirmExternalImport(resources)
          }
        }
      )
      .presentationBackground(.clear)
      .environmentObject(theme)
    }
    .scrollDismissesKeyboard(.interactively)
    .loadingOverlay(viewModel.isPreparingDownload)
    .background(theme.systemBackgroundColor)
    .modifier(IntegrationSearchableModifier(
      isSearchable: viewModel.isSearchable,
      text: $viewModel.searchQuery
    ))
    .searchPresentationToolbarBehavior(.avoidHidingContent)
    .onAppear { viewModel.fetchInitialItems() }
    .onDisappear { viewModel.cancelFetchItems() }
    .errorAlert(error: $viewModel.error)
    // Whole-level download only: an explicit selection needs no second confirmation,
    // and Stream is already confirmed downstream by ExternalImportView.
    .confirmationDialog(
      "download_title".localized,
      isPresented: $viewModel.showingDownloadConfirmation
    ) {
      Button("download_title".localized) {
        viewModel.confirmDownloadFolder()
      }
      Button("cancel_button".localized, role: .cancel) {}
    } message: {
      Text(
        String.localizedStringWithFormat(
          "download_folder_confirmation_message".localized,
          viewModel.downloadableItemCount
        )
      )
    }
    .environment(\.editMode, $viewModel.editMode)
    .onChange(of: viewModel.editMode) { _, newValue in
      tabEditing.wrappedValue = newValue.isEditing
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
            
            // Both fire OUTSIDE edit mode, where the selection is empty — they
            // always mean "everything at this level".
            Button {
              viewModel.onStreamTapped(useSelectedItems: false)
            } label: {
              Label("stream_button", systemImage: "waveform")
            }
            .disabled(viewModel.downloadableItemCount == 0)

            Button(action: viewModel.onDownloadFolderTapped) {
              Label("download_title".localized, systemImage: "arrow.down.to.line")
            }
            // Conservative: on a Jellyfin folder whose loaded page is all subfolders this
            // reads 0 while the server has audiobooks, so Download is briefly unavailable
            // until another page lands. A false negative — never the wrong action.
            .disabled(viewModel.downloadableItemCount == 0 || viewModel.isPreparingDownload)
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
        Picker(selection: $viewModel.layout, label: Text("layout_options_title")) {
          Label("layout_grid_option", systemImage: "square.grid.2x2").tag(IntegrationLayout.Options.grid)
          Label("layout_list_option", systemImage: "list.bullet").tag(IntegrationLayout.Options.list)
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

    Button {
      viewModel.onStreamTapped(useSelectedItems: true)
    } label: {
      Image(systemName: "waveform")
        .accessibilityLabel("stream_button")
    }
    .disabled(viewModel.selectedItems.isEmpty)

    Button(action: viewModel.onDownloadTapped) {
      Image(systemName: "arrow.down.to.line")
        .accessibilityLabel("download_title")
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
