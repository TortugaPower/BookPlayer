//
//  MediaServersView.swift
//  BookPlayer
//
//  Created by Matthew Alnaser on 2026-04-09.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

/// One list of every saved Jellyfin and AudiobookShelf server, in place of the
/// two separate "Download from …" menu items.
///
/// - No servers yet: pick a type and go straight into its connection form.
/// - One or more saved: tap a row to open that server's library browser, or
///   "Add Server" to add another.
struct MediaServersView: View {
  let jellyfinService: JellyfinConnectionService
  let audiobookshelfService: AudiobookShelfConnectionService

  @Environment(\.listState) private var listState
  @EnvironmentObject var theme: ThemeViewModel

  /// Drives the "which integration?" confirmation dialog when the user already
  /// has at least one server saved.
  @State private var showingTypePicker = false

  /// One per integration — flips true to open the matching add-server sheet.
  @State private var addingJellyfin = false
  @State private var addingAudiobookshelf = false

  /// Which server's library browser is currently presented (nil = none).
  @State private var presentedServer: ServerRoute?

  // MARK: - Server Types

  /// Identifies which integration back-end a server belongs to.
  enum ServerType {
    case jellyfin
    case audiobookshelf

    var displayName: String {
      switch self {
      case .jellyfin: "Jellyfin"
      case .audiobookshelf: "AudiobookShelf"
      }
    }

    var icon: ImageResource {
      switch self {
      case .jellyfin: .jellyfinIcon
      case .audiobookshelf: .audiobookshelfIcon
      }
    }
  }

  /// A single server entry for the unified list, abstracting over Jellyfin and ABS data models.
  struct ServerItem: Identifiable {
    let id: String
    let serverName: String
    let serverUrl: String
    let userName: String
    let type: ServerType
  }

  /// Which integration's library browser to present as a sheet. The connection
  /// is activated synchronously before this is set (see `selectServer`), so the
  /// presented view picks up the right active connection.
  enum ServerRoute: String, Identifiable, Hashable {
    case jellyfin
    case audiobookshelf
    var id: String { rawValue }
  }

  // MARK: - Computed Properties

  /// Combines all saved servers from both services into one list.
  private var allServers: [ServerItem] {
    let jellyfinServers = jellyfinService.connections.map { data in
      ServerItem(
        id: data.id,
        serverName: data.serverName,
        serverUrl: data.url.absoluteString,
        userName: data.userName,
        type: .jellyfin
      )
    }
    let absServers = audiobookshelfService.connections.map { data in
      ServerItem(
        id: data.id,
        serverName: data.serverName,
        serverUrl: data.url.absoluteString,
        userName: data.userName,
        type: .audiobookshelf
      )
    }
    return jellyfinServers + absServers
  }

  // MARK: - Body

  var body: some View {
    NavigationStack {
      Form {
        if allServers.isEmpty {
          emptyStateSection
        } else {
          serverListSection
          addServerSection
        }
      }
      .scrollContentBackground(.hidden)
      .background(theme.systemBackgroundColor)
      .navigationTitle("media_servers_title".localized)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          Text("media_servers_title".localized)
            .bpFont(.headline)
            .foregroundStyle(theme.primaryColor)
        }
        ToolbarItem(placement: .cancellationAction) {
          Button {
            listState.activeIntegrationSheet = nil
          } label: {
            Image(systemName: "xmark")
              .foregroundStyle(theme.linkColor)
          }
        }
      }
    }
    .tint(theme.linkColor)
    .environmentObject(theme)
    // The per-server library browser opens as a sheet on top of this list.
    // Pushing JellyfinRootView (which wraps a TabView) onto a NavigationStack
    // auto-pops immediately on iOS 26 — sheet-on-sheet avoids that entirely.
    .sheet(item: $presentedServer) { route in
      switch route {
      case .jellyfin:
        JellyfinRootView(connectionService: jellyfinService, skipServerPicker: true)
          .environmentObject(theme)
      case .audiobookshelf:
        AudiobookShelfRootView(connectionService: audiobookshelfService, skipServerPicker: true)
          .environmentObject(theme)
      }
    }
    // "Which type?" dialog when the user taps Add Server with at least one
    // server already saved.
    .confirmationDialog(
      "media_servers_choose_type_title".localized,
      isPresented: $showingTypePicker,
      titleVisibility: .visible
    ) {
      Button(ServerType.jellyfin.displayName) { handleAddServer(type: .jellyfin) }
      Button(ServerType.audiobookshelf.displayName) { handleAddServer(type: .audiobookshelf) }
    }
    // Add-server sheets, one per integration. Each builds a fresh connection
    // VM in "adding" mode so existing servers aren't disturbed.
    .sheet(isPresented: $addingJellyfin) {
      AddJellyfinServerSheet(service: jellyfinService)
        .environmentObject(theme)
    }
    .sheet(isPresented: $addingAudiobookshelf) {
      AddAudiobookShelfServerSheet(service: audiobookshelfService)
        .environmentObject(theme)
    }
  }

  // MARK: - Empty State

  /// Shown when no servers are configured. Offers direct type selection rows
  /// styled to match the populated server list so they read as tappable.
  @ViewBuilder
  private var emptyStateSection: some View {
    ThemedSection {
      addTypeRow(.jellyfin)
      addTypeRow(.audiobookshelf)
    } header: {
      Text("media_servers_add_prompt".localized)
        .foregroundStyle(theme.secondaryColor)
    }
  }

  /// Empty-state row for a server type. Same layout as populated server rows
  /// (icon + name + chevron) so the affordance reads as a tap target rather
  /// than a static Form row.
  @ViewBuilder
  private func addTypeRow(_ type: ServerType) -> some View {
    Button {
      handleAddServer(type: type)
    } label: {
      HStack(spacing: 12) {
        Image(type.icon)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 28, height: 28)
        Text(type.displayName)
          .foregroundStyle(theme.primaryColor)
        Spacer()
        Image(systemName: "chevron.right")
          .bpFont(.caption)
          .foregroundStyle(theme.secondaryColor)
      }
    }
    .accessibilityLabel(type.displayName)
  }

  // MARK: - Server List

  /// Displays all saved servers from both integrations in a single section.
  /// Each row shows the integration icon, server name, user, and URL.
  @ViewBuilder
  private var serverListSection: some View {
    ThemedSection {
      ForEach(allServers) { server in
        Button {
          selectServer(server)
        } label: {
          HStack(spacing: 12) {
            Image(server.type.icon)
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
              Text(server.serverName)
                .foregroundStyle(theme.primaryColor)
              Text("\(server.userName) — \(server.serverUrl)")
                .bpFont(.caption)
                .foregroundStyle(theme.secondaryColor)
            }
            Spacer()
            Image(systemName: "chevron.right")
              .bpFont(.caption)
              .foregroundStyle(theme.secondaryColor)
          }
        }
        .accessibilityLabel(
          "\(server.type.displayName), \(server.serverName), \(server.userName), \(server.serverUrl)"
        )
      }
    } header: {
      Text("media_servers_title".localized)
        .foregroundStyle(theme.secondaryColor)
    }
  }

  // MARK: - Add Server Button

  @ViewBuilder
  private var addServerSection: some View {
    ThemedSection {
      Button {
        showingTypePicker = true
      } label: {
        Label("integration_add_server_button".localized, systemImage: "plus.circle")
      }
    }
  }

  // MARK: - Actions

  /// Activates the selected server in its connection service and presents the
  /// appropriate library browser as a sheet on top of this list. The browser's
  /// own toolbar provides the "back to servers" affordance via dismiss().
  private func selectServer(_ server: ServerItem) {
    switch server.type {
    case .jellyfin:
      jellyfinService.activateConnection(id: server.id)
      presentedServer = .jellyfin
    case .audiobookshelf:
      audiobookshelfService.activateConnection(id: server.id)
      presentedServer = .audiobookshelf
    }
  }

  /// Opens the add-server sheet for the chosen type. Used for both empty
  /// and populated states — adding a server is always a self-contained sheet
  /// so the existing servers (if any) aren't disturbed.
  private func handleAddServer(type: ServerType) {
    switch type {
    case .jellyfin:
      addingJellyfin = true
    case .audiobookshelf:
      addingAudiobookshelf = true
    }
  }
}

// MARK: - Add Server Sheets

/// Sheet for adding a new Jellyfin server when the user already has existing
/// Jellyfin connections. Wraps `IntegrationConnectionView` in "adding" mode
/// and auto-dismisses when the sign-in completes or the user cancels.
private struct AddJellyfinServerSheet: View {
  let service: JellyfinConnectionService

  @StateObject private var viewModel: JellyfinConnectionViewModel
  @EnvironmentObject var theme: ThemeViewModel
  @Environment(\.dismiss) var dismiss

  init(service: JellyfinConnectionService) {
    self.service = service
    // Create VM then switch to "adding" mode (blank form, disconnected state)
    let vm = JellyfinConnectionViewModel(connectionService: service)
    vm.handleAddServerAction()
    self._viewModel = .init(wrappedValue: vm)
  }

  var body: some View {
    NavigationStack {
      IntegrationConnectionView(viewModel: viewModel, integrationName: "Jellyfin")
        .navigationBarTitleDisplayMode(.inline)
    }
    .tint(theme.linkColor)
    .environmentObject(theme)
    // isAddingServer flips to false on successful sign-in or cancel
    .onChange(of: viewModel.isAddingServer) { _, isAdding in
      if !isAdding { dismiss() }
    }
  }
}

/// Sheet for adding a new AudiobookShelf server when existing ABS connections exist.
/// Same pattern as `AddJellyfinServerSheet`.
private struct AddAudiobookShelfServerSheet: View {
  let service: AudiobookShelfConnectionService

  @StateObject private var viewModel: AudiobookShelfConnectionViewModel
  @EnvironmentObject var theme: ThemeViewModel
  @Environment(\.dismiss) var dismiss

  init(service: AudiobookShelfConnectionService) {
    self.service = service
    let vm = AudiobookShelfConnectionViewModel(connectionService: service)
    vm.handleAddServerAction()
    self._viewModel = .init(wrappedValue: vm)
  }

  var body: some View {
    NavigationStack {
      IntegrationConnectionView(viewModel: viewModel, integrationName: "AudiobookShelf")
        .navigationBarTitleDisplayMode(.inline)
    }
    .tint(theme.linkColor)
    .environmentObject(theme)
    .onChange(of: viewModel.isAddingServer) { _, isAdding in
      if !isAdding { dismiss() }
    }
  }
}
