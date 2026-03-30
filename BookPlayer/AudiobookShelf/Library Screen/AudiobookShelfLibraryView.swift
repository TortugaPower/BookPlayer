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
          AudiobookShelfLibraryGridView(viewModel: viewModel)
            .padding()
        }
      } else {
        AudiobookShelfLibraryListView(viewModel: viewModel)
          .scrollContentBackground(.hidden)
      }
    }
    .scrollDismissesKeyboard(.interactively)
    .background(theme.systemBackgroundColor)
    .environment(\.audiobookshelfService, viewModel.connectionService)
    .modifier(ConditionalSearchableModifier(isSearchable: viewModel.isSearchable, text: $viewModel.searchQuery))
    .searchPresentationToolbarBehavior(.avoidHidingContent)
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
          Label("Grid".localized, systemImage: "square.grid.2x2").tag(AudiobookShelfLayout.Options.grid)
          Label("List".localized, systemImage: "list.bullet").tag(AudiobookShelfLayout.Options.list)
        }
      }
    }
    if viewModel.showsSortPreferences {
      ThemedSection {
        Picker(selection: $viewModel.sortBy, label: Text("Sort by".localized)) {
          Label("sort_most_recent_button", systemImage: "clock").tag(AudiobookShelfLayout.SortBy.recent)
          Label("Title".localized, systemImage: "textformat.abc").tag(AudiobookShelfLayout.SortBy.title)
        }
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

private struct ConditionalSearchableModifier: ViewModifier {
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

struct AudiobookShelfBrowseTabsView: View {
  let library: AudiobookShelfLibraryItem

  @State private var selectedCategory: AudiobookShelfBrowseCategory = .books

  @StateObject private var booksViewModel: AudiobookShelfLibraryViewModel
  @StateObject private var seriesViewModel: AudiobookShelfLibraryViewModel
  @StateObject private var collectionsViewModel: AudiobookShelfLibraryViewModel
  @StateObject private var authorsViewModel: AudiobookShelfLibraryViewModel
  @StateObject private var narratorsViewModel: AudiobookShelfLibraryViewModel

  @EnvironmentObject private var theme: ThemeViewModel

  init(
    library: AudiobookShelfLibraryItem,
    connectionService: AudiobookShelfConnectionService,
    singleFileDownloadService: SingleFileDownloadService,
    navigation: BPNavigation
  ) {
    self.library = library

    self._booksViewModel = .init(
      wrappedValue: AudiobookShelfLibraryViewModel(
        source: .books(libraryID: library.id, filter: nil),
        connectionService: connectionService,
        singleFileDownloadService: singleFileDownloadService,
        navigation: navigation,
        navigationTitle: library.title
      )
    )
    self._seriesViewModel = .init(
      wrappedValue: AudiobookShelfLibraryViewModel(
        source: .entities(libraryID: library.id, category: .series),
        connectionService: connectionService,
        singleFileDownloadService: singleFileDownloadService,
        navigation: navigation,
        navigationTitle: library.title
      )
    )
    self._collectionsViewModel = .init(
      wrappedValue: AudiobookShelfLibraryViewModel(
        source: .entities(libraryID: library.id, category: .collections),
        connectionService: connectionService,
        singleFileDownloadService: singleFileDownloadService,
        navigation: navigation,
        navigationTitle: library.title
      )
    )
    self._authorsViewModel = .init(
      wrappedValue: AudiobookShelfLibraryViewModel(
        source: .entities(libraryID: library.id, category: .authors),
        connectionService: connectionService,
        singleFileDownloadService: singleFileDownloadService,
        navigation: navigation,
        navigationTitle: library.title
      )
    )
    self._narratorsViewModel = .init(
      wrappedValue: AudiobookShelfLibraryViewModel(
        source: .entities(libraryID: library.id, category: .narrators),
        connectionService: connectionService,
        singleFileDownloadService: singleFileDownloadService,
        navigation: navigation,
        navigationTitle: library.title
      )
    )
  }

  var body: some View {
    selectedView
      .background(theme.systemBackgroundColor)
      .safeAreaInset(edge: .bottom) {
        if !selectedViewModel.editMode.isEditing {
          bottomSwitcher
        }
      }
  }

  private var selectedViewModel: AudiobookShelfLibraryViewModel {
    switch selectedCategory {
    case .books:
      booksViewModel
    case .series:
      seriesViewModel
    case .collections:
      collectionsViewModel
    case .authors:
      authorsViewModel
    case .narrators:
      narratorsViewModel
    }
  }

  @ViewBuilder
  private var selectedView: some View {
    switch selectedCategory {
    case .books:
      AudiobookShelfLibraryView(viewModel: booksViewModel)
    case .series:
      AudiobookShelfLibraryView(viewModel: seriesViewModel)
    case .collections:
      AudiobookShelfLibraryView(viewModel: collectionsViewModel)
    case .authors:
      AudiobookShelfLibraryView(viewModel: authorsViewModel)
    case .narrators:
      AudiobookShelfLibraryView(viewModel: narratorsViewModel)
    }
  }

  private var bottomSwitcher: some View {
    HStack(spacing: 6) {
      ForEach(AudiobookShelfBrowseCategory.allCases, id: \.self) { category in
        Button {
          selectedCategory = category
        } label: {
          VStack(spacing: 4) {
            Image(systemName: iconName(for: category))
              .bpFont(.body)
            Text(category.title)
              .bpFont(.caption)
              .lineLimit(1)
              .minimumScaleFactor(0.8)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 10)
          .foregroundStyle(selectedCategory == category ? Color.white : theme.primaryColor)
          .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
              .fill(selectedCategory == category ? theme.linkColor : Color.clear)
          )
        }
        .buttonStyle(.plain)
      }
    }
    .padding(8)
    .background(
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .fill(theme.secondarySystemBackgroundColor.opacity(0.96))
        .overlay(
          RoundedRectangle(cornerRadius: 28, style: .continuous)
            .stroke(theme.separatorColor.opacity(0.25), lineWidth: 1)
        )
    )
    .padding(.horizontal, 16)
    .padding(.top, 8)
    .padding(.bottom, 8)
  }

  private func iconName(for category: AudiobookShelfBrowseCategory) -> String {
    switch category {
    case .books:
      "books.vertical.fill"
    case .series:
      "rectangle.stack.fill"
    case .collections:
      "square.stack.3d.up.fill"
    case .authors:
      "person.2.fill"
    case .narrators:
      "mic.fill"
    }
  }
}
