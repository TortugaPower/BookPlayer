//
//  SearchView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 12/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct SearchView: View {
  @StateObject var viewModel: SearchViewModel
  @State private var loadingState = LoadingOverlayState()
  @EnvironmentObject private var theme: ThemeViewModel
  @Environment(\.libraryService) private var libraryService
  @Environment(\.playerLoaderService) private var playerLoaderService
  @Environment(\.playerState) private var playerState

  init(initModel: @escaping () -> SearchViewModel) {
    self._viewModel = .init(wrappedValue: initModel())
  }

  var body: some View {
    NavigationView {
      Group {
        if viewModel.searchText.isEmpty {
          recentItemsView
        } else {
          searchResultsView
        }
      }
      .miniPlayerSafeAreaInset()
      .applyListStyle(with: theme, background: theme.systemGroupedBackgroundColor)
      .navigationTitle("search_title".localized)
      .searchable(
        text: $viewModel.searchText,
        prompt: "search_title".localized + " " + "library_title".localized
      )
      .onChange(of: viewModel.searchText) { _, newValue in
        viewModel.searchBooks(query: newValue)
      }
      .errorAlert(error: $loadingState.error)
      .loadingOverlay(loadingState.show)
    }
    .onAppear {
      viewModel.loadRecentItems()
    }
  }

  private var recentItemsView: some View {
    List {
      Section("recent_title".localized) {
        ForEach(viewModel.filteredRecentItems) { item in
          rowView(item)
        }
      }
    }
    .listStyle(.insetGrouped)
  }

  private var searchResultsView: some View {
    List {
      ForEach(viewModel.searchSections, id: \.folderName) { section in
        Section(section.displayName) {
          ForEach(section.items) { item in
            rowView(item)
          }
        }
      }
    }
    .listStyle(.insetGrouped)
  }

  @ViewBuilder
  private func rowView(_ item: SimpleLibraryItem) -> some View {
    BookView(item: item) {
      loadPlayer(with: item.relativePath)
    }
    .onTapGesture {
      loadPlayer(with: item.relativePath)
    }
  }

  private func loadPlayer(with relativePath: String) {
    Task {
      do {
        try await playerLoaderService.loadPlayer(relativePath, autoplay: true)
        playerState.showPlayerBinding.wrappedValue = true
      } catch {
        loadingState.error = error
      }
    }
  }
}
