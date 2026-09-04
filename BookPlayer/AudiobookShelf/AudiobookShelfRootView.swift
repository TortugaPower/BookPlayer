//
//  AudiobookShelfRootView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/14/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI
import BookPlayerKit

struct AudiobookShelfRootView: View {
  let connectionService: AudiobookShelfConnectionService

  @StateObject private var connectionViewModel: AudiobookShelfConnectionViewModel

  @State private var resolvedLibrary: AudiobookShelfLibraryItem?
  @State private var availableLibraries: [AudiobookShelfLibraryItem]?
  @State private var loadError: Error?

  private var savedLibraryId: String? {
    connectionService.connection?.selectedLibraryId
  }

  @EnvironmentObject private var singleFileDownloadService: SingleFileDownloadService
  @EnvironmentObject private var externalImportBus: ExternalImportBus
  @EnvironmentObject private var theme: ThemeViewModel

  @Environment(\.dismiss) var dismiss
  @Environment(\.listState) private var listState
  @Environment(\.accountService) private var accountService
  
  init(connectionService: AudiobookShelfConnectionService) {
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
        AudiobookShelfTabRoot(
          source: .books(libraryID: resolvedLibrary?.id ?? "", filter: nil),
          libraryTitle: resolvedLibrary?.title ?? "",
          connectionService: connectionService,
          singleFileDownloadService: singleFileDownloadService,
          accountService: accountService,
          onImportConfirmed: { externalImportBus.send($0) },
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
          accountService: accountService,
          onImportConfirmed: { externalImportBus.send($0) },
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
          accountService: accountService,
          onImportConfirmed: { externalImportBus.send($0) },
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
          accountService: accountService,
          onImportConfirmed: { externalImportBus.send($0) },
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
          accountService: accountService,
          onImportConfirmed: { externalImportBus.send($0) },
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
        // Library/identity loads can fail for many reasons (transient network, token
        // expired, server moved, custom-header proxy issue). The previous "OK" button
        // unconditionally pushed the user into the add-server form, which led people
        // to re-add their server and end up with a duplicate.
        //
        // For the specific "session expired" case (401/403 mid-session) we already know
        // the URL and customHeaders are fine — just the token is stale — so we show a
        // narrower set of actions that funnel into the existing connection's sign-in
        // form (which preserves customHeaders + selectedLibraryId).
        if (loadError as? IntegrationError)?.isSessionExpired == true {
          // Session expired: Retry would just hit the same 401, so omit it.
          // Titled "Sign In", not "Connection Details": this routes to `prepareReauth()`, which opens
          // the sign-in flow at the server-URL step, not the read-only details screen. The old title
          // described the old destination — and for VoiceOver the label *is* the whole announcement,
          // so the mismatch would leave the user in an unexpected text field.
          Button("integration_sign_in_button".localized) {
            loadError = nil
            // `prepareReauth()` rather than `signInFlow = nil`: the details screen is read-only and
            // its only button is Log out, so landing there left the user with no way to sign back in
            // — fatal for an SSO connection, which has no password to fall back on.
            connectionViewModel.prepareReauth()
            showConnectionForm = true
          }
          Button("cancel_button".localized, role: .cancel) {
            loadError = nil
            dismiss()
          }
        } else {
          Button("integration_retry_button".localized) {
            loadError = nil
            Task { await loadLibraries() }
          }
          Button("integration_connection_details_title".localized) {
            loadError = nil
            connectionViewModel.signInFlow = nil
            showConnectionForm = true
          }
          Button("cancel_button".localized, role: .cancel) {
            loadError = nil
            dismiss()
          }
        }
      },
      message: { Text(loadError?.localizedDescription ?? "") }
    )
    .sheet(isPresented: $showConnectionForm) {
      // The flow owns its NavigationStack and its own cancel affordances (Cancel for Add Server,
      // an X otherwise) — no outer wrapping.
      IntegrationConnectionFlowView(viewModel: connectionViewModel, kind: .audiobookshelf, integrationName: "AudiobookShelf")
        .environmentObject(theme)
    }
    .sheet(isPresented: $showLibraryPicker) {
      libraryPickerSheet
    }
    .environmentObject(theme)
    .onChange(of: availableLibraries) { _, libraries in
      if let libraries, libraries.count > 1, resolvedLibrary == nil {
        showLibraryPicker = true
      }
    }
    .onChange(of: connectionService.connection?.id) { _, newValue in
      // Same as JellyfinRootView: the active connection was deleted out from under this library;
      // follow the deletion out instead of stranding a dead screen.
      if newValue == nil { dismiss() }
    }
    .onChange(of: connectionViewModel.signInCompletedAt) { _, newValue in
      guard newValue != nil else { return }
      showConnectionForm = false
      resolvedLibrary = nil
      Task { await loadLibraries() }
    }
    .task {
      if connectionService.connections.isEmpty {
        showConnectionForm = true
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
        // The card fill every ThemedSection row gets; a bare List row renders the system fill,
        // which is the one unthemed surface on this screen.
        .listRowBackground(theme.tertiarySystemBackgroundColor)
      }
      .applyListStyle(with: theme, background: theme.systemBackgroundColor)
      // Until a library is chosen there is nothing behind this sheet to land on — swiping it away
      // would strand the user on an empty integration library. Cancel remains the way out, and it
      // correctly backs out of the whole server. Once a library exists (reopening the picker to
      // switch), swipe-to-dismiss behaves normally.
      .interactiveDismissDisabled(resolvedLibrary == nil)
      .navigationTitle("library_title".localized)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("cancel_button".localized) {
            // No library chosen yet — there's nothing to browse, so back out
            // to the server picker rather than leave the user on a disabled view.
            if resolvedLibrary == nil {
              showLibraryPicker = false
              dismiss()
            } else {
              showLibraryPicker = false
            }
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
  let accountService: AccountService
  let onImportConfirmed: ([SimpleExternalResource]) -> Void
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
    accountService: AccountService,
    onImportConfirmed: @escaping ([SimpleExternalResource]) -> Void,
    onDismiss: @escaping () -> Void,
    onSwitchLibrary: (() -> Void)? = nil,
    dismissAll: DismissAction? = nil
  ) {
    self.connectionService = connectionService
    self.singleFileDownloadService = singleFileDownloadService
    self.accountService = accountService
    self.onImportConfirmed = onImportConfirmed
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
        accountService: accountService,
        onImportConfirmed: onImportConfirmed,
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
                accountService: accountService,
                onImportConfirmed: onImportConfirmed,
                navigation: navigation,
                navigationTitle: title
              )
            )
          case .details(let item):
            AudiobookShelfAudiobookDetailsView(
              initModel: {
                AudiobookShelfAudiobookDetailsViewModel(
                  item: item,
                  connectionService: connectionService,
                  singleFileDownloadService: singleFileDownloadService,
                  accountService: accountService,
                  onImportConfirmed: onImportConfirmed,
                  navigation: navigation
                )
              }
            ) {
              onDismiss()
            }
          case .subscribe:
            ExternalSyncIntroView()
          }
        }
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
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
    .toolbar((isEditing || !navigation.path.isEmpty) ? .hidden : .visible, for: .tabBar)
    .tint(theme.linkColor)
    .sheet(isPresented: $showConnectionDetails) {
      NavigationStack {
        IntegrationSettingsView(integrationName: "AudiobookShelf") {
          AudiobookShelfConnectionViewModel(
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
                showConnectionDetails = false
              }
            }
          }
        }
      }
      .tint(theme.linkColor)
      .environmentObject(theme)
    }
    .task {
      navigation.dismiss = onDismiss
    }
  }
}
