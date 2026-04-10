//
//  AudiobookShelfRootView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/14/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct AudiobookShelfRootView: View {
  let connectionService: AudiobookShelfConnectionService
  /// When `true`, skips the per-integration server picker on launch.
  /// Used when the caller (e.g. MediaServersView) has already activated the desired server.
  var skipServerPicker: Bool = false

  @StateObject private var connectionViewModel: AudiobookShelfConnectionViewModel

  @State private var resolvedLibrary: AudiobookShelfLibraryItem?
  @State private var availableLibraries: [AudiobookShelfLibraryItem]?
  @State private var loadError: Error?

  private var savedLibraryId: String? {
    connectionService.connection?.selectedLibraryId
  }

  @EnvironmentObject private var singleFileDownloadService: SingleFileDownloadService
  @EnvironmentObject private var theme: ThemeViewModel

  @Environment(\.dismiss) var dismiss
  @Environment(\.listState) private var listState

  init(connectionService: AudiobookShelfConnectionService, skipServerPicker: Bool = false) {
    self.connectionService = connectionService
    self.skipServerPicker = skipServerPicker
    self._connectionViewModel = .init(
      wrappedValue: .init(connectionService: connectionService)
    )
  }

  @State private var showLibraryPicker = false
  @State private var showConnectionForm = false
  @State private var showServerPicker = false
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
        AudiobookShelfTabRoot(
          source: .books(libraryID: resolvedLibrary?.id ?? "", filter: nil),
          libraryTitle: resolvedLibrary?.title ?? "",
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
      Tab("Series", systemImage: "rectangle.stack.fill") {
        AudiobookShelfTabRoot(
          source: .entities(libraryID: resolvedLibrary?.id ?? "", category: .series),
          libraryTitle: resolvedLibrary?.title ?? "",
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
      Tab("Collections", systemImage: "square.stack.3d.up.fill") {
        AudiobookShelfTabRoot(
          source: .entities(libraryID: resolvedLibrary?.id ?? "", category: .collections),
          libraryTitle: resolvedLibrary?.title ?? "",
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
        AudiobookShelfTabRoot(
          source: .entities(libraryID: resolvedLibrary?.id ?? "", category: .authors),
          libraryTitle: resolvedLibrary?.title ?? "",
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
      Tab("Narrators", systemImage: "mic.fill") {
        AudiobookShelfTabRoot(
          source: .entities(libraryID: resolvedLibrary?.id ?? "", category: .narrators),
          libraryTitle: resolvedLibrary?.title ?? "",
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
        IntegrationConnectionView(viewModel: connectionViewModel, integrationName: "AudiobookShelf")
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
        resolvedLibrary = nil
        Task { await loadLibraries() }
      }
    }
    .sheet(isPresented: $showServerPicker) {
      NavigationStack {
        IntegrationServerPickerView(viewModel: connectionViewModel) { serverID in
          connectionViewModel.handleActivateAction(id: serverID)
          showServerPicker = false
          resolvedLibrary = nil
          Task { await loadLibraries() }
        }
        .toolbar {
          ToolbarItem(placement: .principal) {
            Text("AudiobookShelf")
              .bpFont(.headline)
              .foregroundStyle(theme.primaryColor)
          }
          ToolbarItemGroup(placement: .cancellationAction) {
            Button { showServerPicker = false } label: {
              Image(systemName: "xmark")
                .foregroundStyle(theme.linkColor)
            }
          }
        }
        .navigationBarTitleDisplayMode(.inline)
      }
      .tint(theme.linkColor)
      .environmentObject(theme)
    }
    .task {
      if connectionService.connections.isEmpty {
        showConnectionForm = true
      } else if !skipServerPicker && connectionService.connections.count > 1, resolvedLibrary == nil {
        showServerPicker = true
      } else if resolvedLibrary == nil {
        await loadLibraries()
      }
    }
  }

  // MARK: - Library Picker

  private func selectLibrary(_ library: AudiobookShelfLibraryItem) {
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
            AudiobookShelfLibraryItemImageView(item: library)
              .frame(width: 50, height: 50)
            VStack(alignment: .leading) {
              Text(library.title)
                .foregroundStyle(theme.primaryColor)
              if let subtitle = library.subtitle {
                Text(subtitle)
                  .font(.caption)
                  .foregroundStyle(theme.secondaryColor)
              }
            }
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
      let libraries = try await connectionService.fetchLibraries()
      let bookLibraries = libraries
        .filter { $0.mediaType == "book" }
        .map(AudiobookShelfLibraryItem.init(library:))

      if bookLibraries.count == 1, let library = bookLibraries.first {
        selectLibrary(library)
      } else if let savedId = savedLibraryId,
                let saved = bookLibraries.first(where: { $0.id == savedId }) {
        selectLibrary(saved)
        availableLibraries = bookLibraries
      } else {
        availableLibraries = bookLibraries
      }
    } catch is CancellationError {
      // ignore
    } catch {
      loadError = error
    }
  }
}


// MARK: - Per-Tab NavigationStack

/// Each tab owns its own NavigationStack and BPNavigation.
/// This matches the MainView pattern where each tab has independent navigation.
private struct AudiobookShelfTabRoot: View {
  let connectionService: AudiobookShelfConnectionService
  let singleFileDownloadService: SingleFileDownloadService
  let onDismiss: () -> Void
  var onSwitchLibrary: (() -> Void)?
  var dismissAll: DismissAction?

  @StateObject private var navigation = BPNavigation()
  @StateObject var viewModel: AudiobookShelfLibraryViewModel
  @State private var isEditing = false
  @State private var showConnectionDetails = false

  @EnvironmentObject private var theme: ThemeViewModel

  init(
    source: AudiobookShelfLibraryViewSource,
    libraryTitle: String,
    connectionService: AudiobookShelfConnectionService,
    singleFileDownloadService: SingleFileDownloadService,
    onDismiss: @escaping () -> Void,
    onSwitchLibrary: (() -> Void)? = nil,
    dismissAll: DismissAction? = nil
  ) {
    self.connectionService = connectionService
    self.singleFileDownloadService = singleFileDownloadService
    self.dismissAll = dismissAll
    self.onDismiss = onDismiss
    self.onSwitchLibrary = onSwitchLibrary

    let navigation = BPNavigation()
    self._navigation = .init(wrappedValue: navigation)
    self._viewModel = .init(
      wrappedValue: AudiobookShelfLibraryViewModel(
        source: source,
        connectionService: connectionService,
        singleFileDownloadService: singleFileDownloadService,
        navigation: navigation,
        navigationTitle: libraryTitle
      )
    )
  }

  var body: some View {
    NavigationStack(path: $navigation.path) {
      AudiobookShelfLibraryView(viewModel: viewModel)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: AudiobookShelfLibraryLevelData.self) { destination in
          switch destination {
          case .library(source: let source, title: let title):
            AudiobookShelfLibraryView(
              viewModel: AudiobookShelfLibraryViewModel(
                source: source,
                connectionService: connectionService,
                singleFileDownloadService: singleFileDownloadService,
                navigation: navigation,
                navigationTitle: title
              )
            )
          case .details(let item):
            AudiobookShelfAudiobookDetailsView(
              viewModel: AudiobookShelfAudiobookDetailsViewModel(
                item: item,
                connectionService: connectionService,
                singleFileDownloadService: singleFileDownloadService
              )
            ) {
              onDismiss()
            }
          }
        }
        .toolbar {
          ToolbarItemGroup(placement: .cancellationAction) {
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
      NavigationStack {
        IntegrationSettingsView(
          viewModel: AudiobookShelfConnectionViewModel(
            connectionService: connectionService,
            mode: .viewDetails
          ),
          integrationName: "AudiobookShelf"
        )
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
}
