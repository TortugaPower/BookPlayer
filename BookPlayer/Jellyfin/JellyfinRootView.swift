//
//  JellyfinRootView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 7/6/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct JellyfinRootView: View {
  let connectionService: JellyfinConnectionService

  @StateObject private var connectionViewModel: JellyfinConnectionViewModel

  @State private var resolvedLibrary: JellyfinLibraryItem?
  @State private var availableLibraries: [JellyfinLibraryItem]?
  @State private var loadError: Error?

  private var savedLibraryId: String? {
    connectionService.connection?.selectedLibraryId
  }

  @EnvironmentObject private var singleFileDownloadService: SingleFileDownloadService
  @EnvironmentObject private var theme: ThemeViewModel

  @Environment(\.dismiss) var dismiss
  @Environment(\.listState) private var listState

  init(connectionService: JellyfinConnectionService) {
    self.connectionService = connectionService
    self._connectionViewModel = .init(
      wrappedValue: .init(connectionService: connectionService)
    )
  }

  @State private var showLibraryPicker = false
  @State private var showConnectionForm = false
  @State private var isLoadingLibraries = false

  private var isReady: Bool {
    resolvedLibrary != nil
  }

  private var switchLibraryAction: (() -> Void)? {
    guard let libraries = availableLibraries, libraries.count > 1 else { return nil }
    return { showLibraryPicker = true }
  }

  var body: some View {
    TabView {
      Tab("books_title", systemImage: "books.vertical.fill") {
        JellyfinTabRoot(
          library: resolvedLibrary,
          connectionService: connectionService,
          singleFileDownloadService: singleFileDownloadService,
          onDismiss: { listState.activeIntegrationSheet = nil },
          onSwitchLibrary: switchLibraryAction,
          dismissAll: dismiss
        )
        .id(resolvedLibrary?.id)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(theme.secondarySystemBackgroundColor, for: .tabBar)
      }
      Tab("Authors", systemImage: "person.2.fill") {
        JellyfinEntityTabRoot<JellyfinAuthorsListViewModel>(
          connectionService: connectionService,
          singleFileDownloadService: singleFileDownloadService,
          onDismiss: { listState.activeIntegrationSheet = nil },
          onSwitchLibrary: switchLibraryAction,
          makeViewModel: { nav in
            JellyfinAuthorsListViewModel(
              parentID: resolvedLibrary?.id,
              connectionService: connectionService,
              singleFileDownloadService: singleFileDownloadService,
              navigation: nav,
              navigationTitle: "Authors"
            )
          }
        )
        .id(resolvedLibrary?.id)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(theme.secondarySystemBackgroundColor, for: .tabBar)
      }
    }
    .toolbarColorScheme(theme.useDarkVariant ? .dark : .light, for: .tabBar)
    .tint(theme.linkColor)
    .disabled(!isReady)
    .loadingOverlay(isLoadingLibraries)
    .alert(
      "error_title".localized,
      isPresented: .init(get: { loadError != nil }, set: { if !$0 { loadError = nil } }),
      actions: {
        Button("ok_button".localized) {
          loadError = nil
          showConnectionForm = true
        }
      },
      message: { Text(loadError?.localizedDescription ?? "") }
    )
    .sheet(isPresented: $showConnectionForm) {
      NavigationStack {
        IntegrationConnectionView(viewModel: connectionViewModel, integrationName: "Jellyfin")
          .toolbar {
            ToolbarItemGroup(placement: .cancellationAction) {
              Button { dismiss() } label: {
                Image(systemName: "xmark")
                  .foregroundStyle(theme.linkColor)
              }
            }
            if connectionService.connection != nil {
              ToolbarItemGroup(placement: .confirmationAction) {
                Button("integration_connect_button") {
                  showConnectionForm = false
                  Task { await loadLibraries() }
                }
              }
            }
          }
          .navigationBarTitleDisplayMode(.inline)
      }
      .tint(theme.linkColor)
      .environmentObject(theme)
      .interactiveDismissDisabled()
    }
    .sheet(isPresented: $showLibraryPicker) {
      libraryPickerSheet
        .interactiveDismissDisabled(resolvedLibrary == nil)
    }
    .environmentObject(theme)
    .onChange(of: availableLibraries) { _, libraries in
      if let libraries, libraries.count > 1, resolvedLibrary == nil {
        showLibraryPicker = true
      }
    }
    .onChange(of: connectionViewModel.connectionState) { _, newValue in
      if newValue == .connected {
        showConnectionForm = false
        if resolvedLibrary == nil {
          Task { await loadLibraries() }
        }
      }
    }
    .task {
      if connectionService.connection == nil {
        showConnectionForm = true
      } else if resolvedLibrary == nil {
        await loadLibraries()
      }
    }
  }

  // MARK: - Library Picker

  private func selectLibrary(_ library: JellyfinLibraryItem) {
    resolvedLibrary = library
    connectionService.saveSelectedLibrary(id: library.id)
    showLibraryPicker = false
  }

  private var libraryPickerSheet: some View {
    NavigationStack {
      List(availableLibraries ?? []) { library in
        Button {
          selectLibrary(library)
        } label: {
          HStack {
            JellyfinLibraryItemImageView(item: library)
              .frame(width: 50, height: 50)
            Text(library.name)
              .foregroundStyle(theme.primaryColor)
            Spacer()
            if library.id == resolvedLibrary?.id {
              Image(systemName: "checkmark")
                .foregroundStyle(theme.linkColor)
            }
          }
        }
      }
      .scrollContentBackground(.hidden)
      .background(theme.systemBackgroundColor)
      .navigationTitle("library_title".localized)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        if resolvedLibrary != nil {
          ToolbarItem(placement: .cancellationAction) {
            Button("done_title".localized) { showLibraryPicker = false }
          }
        }
      }
    }
    .environmentObject(theme)
  }

  private func loadLibraries() async {
    isLoadingLibraries = true
    defer { isLoadingLibraries = false }
    do {
      let libraries = try await connectionService.fetchTopLevelItems()
      if libraries.count == 1, let library = libraries.first {
        selectLibrary(library)
      } else if let savedId = savedLibraryId,
                let saved = libraries.first(where: { $0.id == savedId }) {
        selectLibrary(saved)
        availableLibraries = libraries
      } else {
        availableLibraries = libraries
      }
    } catch is CancellationError {
      // ignore
    } catch {
      loadError = error
    }
  }
}

// MARK: - Books Tab (folder-based, same as original)

private struct JellyfinTabRoot: View {
  let connectionService: JellyfinConnectionService
  let singleFileDownloadService: SingleFileDownloadService
  let onDismiss: () -> Void
  var onSwitchLibrary: (() -> Void)?
  var dismissAll: DismissAction?

  @StateObject private var navigation = BPNavigation()
  @StateObject var viewModel: JellyfinLibraryViewModel
  @State private var isEditing = false
  @State private var showConnectionDetails = false

  @EnvironmentObject private var theme: ThemeViewModel

  init(
    library: JellyfinLibraryItem?,
    connectionService: JellyfinConnectionService,
    singleFileDownloadService: SingleFileDownloadService,
    onDismiss: @escaping () -> Void,
    onSwitchLibrary: (() -> Void)? = nil,
    dismissAll: DismissAction? = nil
  ) {
    self.connectionService = connectionService
    self.singleFileDownloadService = singleFileDownloadService
    self.onDismiss = onDismiss
    self.onSwitchLibrary = onSwitchLibrary
    self.dismissAll = dismissAll

    let navigation = BPNavigation()
    self._navigation = .init(wrappedValue: navigation)
    self._viewModel = .init(
      wrappedValue: JellyfinLibraryViewModel(
        folderID: library?.id,
        connectionService: connectionService,
        singleFileDownloadService: singleFileDownloadService,
        navigation: navigation,
        navigationTitle: library?.name ?? ""
      )
    )
  }

  var body: some View {
    NavigationStack(path: $navigation.path) {
      JellyfinLibraryView(viewModel: viewModel)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: JellyfinLibraryLevelData.self) { destination in
          destinationView(for: destination)
        }
        .toolbar {
          ToolbarItemGroup(placement: .cancellationAction) {
            cogMenu
          }
          if let onSwitchLibrary {
            ToolbarItem(placement: .topBarTrailing) {
              Button {
                onSwitchLibrary()
              } label: {
                Image(systemName: "building.columns")
                  .foregroundStyle(theme.linkColor)
              }
              .accessibilityLabel("Switch Library")
            }
          }
        }
    }
    .environment(\.tabEditing, $isEditing)
    .toolbar(isEditing ? .hidden : .visible, for: .tabBar)
    .tint(theme.linkColor)
    .sheet(isPresented: $showConnectionDetails) {
      connectionDetailsSheet
    }
    .task {
      navigation.dismiss = onDismiss
    }
  }

  @ViewBuilder
  private func destinationView(for destination: JellyfinLibraryLevelData) -> some View {
    switch destination {
    case .topLevel(let libraryName):
      JellyfinLibraryView(
        viewModel: JellyfinLibraryViewModel(
          folderID: nil,
          connectionService: connectionService,
          singleFileDownloadService: singleFileDownloadService,
          navigation: navigation,
          navigationTitle: libraryName
        )
      )
    case .folder(let item):
      JellyfinLibraryView(
        viewModel: JellyfinLibraryViewModel(
          folderID: item.id,
          connectionService: connectionService,
          singleFileDownloadService: singleFileDownloadService,
          navigation: navigation,
          navigationTitle: item.name
        )
      )
    case .authorBooks(let authorID, let authorName, let parentID):
      JellyfinLibraryView(
        viewModel: JellyfinAuthorBooksViewModel(
          authorID: authorID,
          parentID: parentID,
          connectionService: connectionService,
          singleFileDownloadService: singleFileDownloadService,
          navigation: navigation,
          navigationTitle: authorName
        )
      )
    case .narratorBooks(let personID, let personName, let parentID):
      JellyfinLibraryView(
        viewModel: JellyfinNarratorBooksViewModel(
          personID: personID,
          parentID: parentID,
          connectionService: connectionService,
          singleFileDownloadService: singleFileDownloadService,
          navigation: navigation,
          navigationTitle: personName
        )
      )
    case .details(let item):
      JellyfinAudiobookDetailsView(
        viewModel: JellyfinAudiobookDetailsViewModel(
          item: item,
          connectionService: connectionService,
          singleFileDownloadService: singleFileDownloadService
        )
      ) {
        onDismiss()
      }
    }
  }

  private var cogMenu: some View {
    Menu {
      Button {
        showConnectionDetails = true
      } label: {
        Label("integration_connection_details_title".localized, systemImage: "server.rack")
      }
      Button {
        onDismiss()
      } label: {
        Label("voiceover_close_button", systemImage: "xmark")
      }
    } label: {
      Image(systemName: "gearshape")
        .foregroundStyle(theme.linkColor)
    }
    .accessibilityLabel("settings_title")
  }

  private var connectionDetailsSheet: some View {
    NavigationStack {
      IntegrationSettingsView(integrationName: "Jellyfin") {
        JellyfinConnectionViewModel(
          connectionService: connectionService,
          mode: .viewDetails
        )
      }
      .toolbar {
        if connectionService.connection == nil {
          ToolbarItemGroup(placement: .cancellationAction) {
            Button {
              onDismiss()
            } label: {
              Image(systemName: "xmark")
                .foregroundStyle(theme.linkColor)
            }
          }
        } else {
          ToolbarItemGroup(placement: .confirmationAction) {
            Button("done_title".localized) {
              showConnectionDetails = false
            }
          }
        }
      }
    }
    .tint(theme.linkColor)
    .environmentObject(theme)
  }
}

// MARK: - Entity Tab Root (Authors / Narrators)
// Reuses JellyfinTabRoot structure but with a list-specific ViewModel

private struct JellyfinEntityTabRoot<ViewModel: IntegrationLibraryViewModelProtocol>: View
where ViewModel.Item == JellyfinLibraryItem {
  let connectionService: JellyfinConnectionService
  let singleFileDownloadService: SingleFileDownloadService
  let onDismiss: () -> Void
  var onSwitchLibrary: (() -> Void)?
  var dismissAll: DismissAction?

  @StateObject private var navigation = BPNavigation()
  @StateObject var viewModel: ViewModel
  @State private var isEditing = false
  @State private var showConnectionDetails = false

  @EnvironmentObject private var theme: ThemeViewModel

  init(
    connectionService: JellyfinConnectionService,
    singleFileDownloadService: SingleFileDownloadService,
    onDismiss: @escaping () -> Void,
    onSwitchLibrary: (() -> Void)? = nil,
    dismissAll: DismissAction? = nil,
    makeViewModel: (BPNavigation) -> ViewModel
  ) {
    self.connectionService = connectionService
    self.singleFileDownloadService = singleFileDownloadService
    self.onDismiss = onDismiss
    self.onSwitchLibrary = onSwitchLibrary
    self.dismissAll = dismissAll

    let navigation = BPNavigation()
    let vm = makeViewModel(navigation)
    self._navigation = .init(wrappedValue: navigation)
    self._viewModel = .init(wrappedValue: vm)
  }

  var body: some View {
    NavigationStack(path: $navigation.path) {
      JellyfinLibraryView(viewModel: viewModel)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: JellyfinLibraryLevelData.self) { destination in
          JellyfinTabRoot.sharedDestinationView(
            for: destination,
            connectionService: connectionService,
            singleFileDownloadService: singleFileDownloadService,
            navigation: navigation,
            onDismiss: onDismiss
          )
        }
        .toolbar {
          ToolbarItemGroup(placement: .cancellationAction) {
            JellyfinTabRoot.cogMenuView(
              theme: theme,
              connectionService: connectionService,
              showConnectionDetails: $showConnectionDetails,
              onDismiss: onDismiss
            )
          }
          if let onSwitchLibrary {
            ToolbarItem(placement: .topBarTrailing) {
              Button {
                onSwitchLibrary()
              } label: {
                Image(systemName: "building.columns")
                  .foregroundStyle(theme.linkColor)
              }
              .accessibilityLabel("Switch Library")
            }
          }
        }
    }
    .environment(\.tabEditing, $isEditing)
    .toolbar(isEditing ? .hidden : .visible, for: .tabBar)
    .tint(theme.linkColor)
    .sheet(isPresented: $showConnectionDetails) {
      JellyfinTabRoot.connectionDetailsSheetView(
        connectionService: connectionService,
        showConnectionDetails: $showConnectionDetails,
        theme: theme,
        dismissAll: dismissAll
      )
    }
    .task {
      navigation.dismiss = onDismiss
    }
  }
}

// MARK: - Shared helpers on JellyfinTabRoot

extension JellyfinTabRoot {
  @ViewBuilder
  static func sharedDestinationView(
    for destination: JellyfinLibraryLevelData,
    connectionService: JellyfinConnectionService,
    singleFileDownloadService: SingleFileDownloadService,
    navigation: BPNavigation,
    onDismiss: @escaping () -> Void
  ) -> some View {
    switch destination {
    case .topLevel(let libraryName):
      JellyfinLibraryView(
        viewModel: JellyfinLibraryViewModel(
          folderID: nil,
          connectionService: connectionService,
          singleFileDownloadService: singleFileDownloadService,
          navigation: navigation,
          navigationTitle: libraryName
        )
      )
    case .folder(let item):
      JellyfinLibraryView(
        viewModel: JellyfinLibraryViewModel(
          folderID: item.id,
          connectionService: connectionService,
          singleFileDownloadService: singleFileDownloadService,
          navigation: navigation,
          navigationTitle: item.name
        )
      )
    case .authorBooks(let authorID, let authorName, let parentID):
      JellyfinLibraryView(
        viewModel: JellyfinAuthorBooksViewModel(
          authorID: authorID,
          parentID: parentID,
          connectionService: connectionService,
          singleFileDownloadService: singleFileDownloadService,
          navigation: navigation,
          navigationTitle: authorName
        )
      )
    case .narratorBooks(let personID, let personName, let parentID):
      JellyfinLibraryView(
        viewModel: JellyfinNarratorBooksViewModel(
          personID: personID,
          parentID: parentID,
          connectionService: connectionService,
          singleFileDownloadService: singleFileDownloadService,
          navigation: navigation,
          navigationTitle: personName
        )
      )
    case .details(let item):
      JellyfinAudiobookDetailsView(
        viewModel: JellyfinAudiobookDetailsViewModel(
          item: item,
          connectionService: connectionService,
          singleFileDownloadService: singleFileDownloadService
        )
      ) {
        onDismiss()
      }
    }
  }

  static func cogMenuView(
    theme: ThemeViewModel,
    connectionService: JellyfinConnectionService,
    showConnectionDetails: Binding<Bool>,
    onDismiss: @escaping () -> Void
  ) -> some View {
    Menu {
      Button {
        showConnectionDetails.wrappedValue = true
      } label: {
        Label("integration_connection_details_title".localized, systemImage: "server.rack")
      }
      Button {
        onDismiss()
      } label: {
        Label("voiceover_close_button", systemImage: "xmark")
      }
    } label: {
      Image(systemName: "gearshape")
        .foregroundStyle(theme.linkColor)
    }
  }

  static func connectionDetailsSheetView(
    connectionService: JellyfinConnectionService,
    showConnectionDetails: Binding<Bool>,
    theme: ThemeViewModel,
    dismissAll: DismissAction? = nil
  ) -> some View {
    NavigationStack {
      IntegrationSettingsView(integrationName: "Jellyfin") {
        JellyfinConnectionViewModel(
          connectionService: connectionService,
          mode: .viewDetails
        )
      }
      .toolbar {
        if connectionService.connection == nil {
          ToolbarItemGroup(placement: .cancellationAction) {
            Button {
              dismissAll?()
            } label: {
              Image(systemName: "xmark")
                .foregroundStyle(theme.linkColor)
            }
          }
        } else {
          ToolbarItemGroup(placement: .confirmationAction) {
            Button("done_title".localized) {
              showConnectionDetails.wrappedValue = false
            }
          }
        }
      }
    }
    .tint(theme.linkColor)
    .environmentObject(theme)
  }
}
