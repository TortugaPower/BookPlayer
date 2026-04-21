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
  @EnvironmentObject private var theme: ThemeViewModel
  @Environment(\.accountService) private var accountService

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
    ZStack {
      Group {
        if viewModel.layout == .grid {
          JellyfinLibraryGridView(viewModel: viewModel)
            .padding()
        } else {
          JellyfinLibraryListView(viewModel: viewModel)
        }
      }
      .scrollContentBackground(.hidden)
      .background(theme.systemBackgroundColor)
      
      if viewModel.showingDownloadConfirmation {
        // Dimmed background
        Color.black.opacity(0.4)
          .ignoresSafeArea()
          .onTapGesture {
            // Allow tapping outside to dismiss
            withAnimation { viewModel.showingDownloadConfirmation = false }
          }
        // This prevents touches from passing through to the view behind it
          .allowsHitTesting(true)
        
        // The charming card aligned to the bottom
        VStack {
          Spacer()
          
          SyncInvitationCard(
            totalItems: viewModel.useSelectedItems ? viewModel.selectedItems.count : viewModel.totalItems,
            subscription: accountService.accessLevel,
            onDownload: {
              withAnimation { viewModel.showingDownloadConfirmation = false }
              viewModel.handleImportItems(useSelectedItems: viewModel.useSelectedItems)
            },
            onSync: {
              withAnimation { viewModel.showingDownloadConfirmation = false }
              viewModel.navigation.path.append(JellyfinLibraryLevelData.subscribe)
            },
            onCancel: {
              withAnimation { viewModel.showingDownloadConfirmation = false }
            }
          )
          .padding(.horizontal, 16)
          // Push it slightly off the bottom edge for a floating look
          .padding(.bottom, 32)
        }
        // Animate the card sliding in from the bottom
        .transition(.move(edge: .bottom).combined(with: .opacity))
        // Ensure it sits above everything else in the ZStack
        .zIndex(1)
      }
    }
    .environment(\.jellyfinService, viewModel.connectionService)
    .onAppear { viewModel.fetchInitialItems() }
    .onDisappear { viewModel.cancelFetchItems() }
    .errorAlert(error: $viewModel.error)
    .environment(\.editMode, $viewModel.editMode)
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
        ThemedSection {
          Button(action: viewModel.onEditToggleSelectTapped) {
            Label("select_title".localized, systemImage: "checkmark.circle")
          }
          Button {
            if accountService.hasLiteEnabled() {
              viewModel.handleImportItems(useSelectedItems: false)
            } else {
              withAnimation {
                viewModel.onDownloadFolderTapped()
              }
            }
          } label: {
            Label("download_title".localized, systemImage: "arrow.down.to.line")
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
    ThemedSection {
      Picker(selection: $viewModel.layout, label: Text("Layout options".localized)) {
        Label("Grid".localized, systemImage: "square.grid.2x2").tag(JellyfinLayout.Options.grid)
        Label("List".localized, systemImage: "list.bullet").tag(JellyfinLayout.Options.list)
      }
    }
    ThemedSection {
      Picker(selection: $viewModel.sortBy, label: Text("Sort by".localized)) {
        Text("Default".localized).tag(JellyfinLayout.SortBy.smart)
        Label("sort_most_recent_button", systemImage: "clock").tag(JellyfinLayout.SortBy.recent)
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

    Button {
      if accountService.hasLiteEnabled() {
        viewModel.handleImportItems(useSelectedItems: true)
      } else {
        viewModel.useSelectedItems = true
        withAnimation { viewModel.showingDownloadConfirmation = true }
      }
    } label: {
      Image(systemName: "arrow.down.to.line")
    }
    .disabled(viewModel.selectedItems.isEmpty)
  }
}
