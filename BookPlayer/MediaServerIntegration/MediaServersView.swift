//
//  MediaServersView.swift
//  BookPlayer
//
//  Created by Matthew Alnaser on 2026-04-09.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

/// Unified view that displays all saved media servers (Jellyfin and AudiobookShelf)
/// in a single list. Replaces the separate "Download from Jellyfin" and
/// "Download from AudiobookShelf" menu items with one entry point.
///
/// Flow:
/// - 0 servers: shows a type picker so the user can add their first server.
/// - 1+ servers: shows the unified list; tapping a server activates it and
///   navigates to its library browser (JellyfinRootView / AudiobookShelfRootView).
/// - "Add Server" opens a type picker, then the connection form for that type.
struct MediaServersView: View {
  let jellyfinService: JellyfinConnectionService
  let audiobookshelfService: AudiobookShelfConnectionService

  @Environment(\.listState) private var listState
  @EnvironmentObject var theme: ThemeViewModel

  /// Drives the confirmation dialog for choosing a server type when adding
  @State private var showingTypePicker = false

  /// Controls the add-server sheet for each integration type
  @State private var addingJellyfin = false
  @State private var addingAudiobookshelf = false

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
    // Type picker dialog shown when adding a server while others already exist
    .confirmationDialog(
      "media_servers_choose_type_title".localized,
      isPresented: $showingTypePicker,
      titleVisibility: .visible
    ) {
      Button("Jellyfin") { handleAddServer(type: .jellyfin) }
      Button("AudiobookShelf") { handleAddServer(type: .audiobookshelf) }
    }
    // Add-server sheets — each creates a fresh connection VM in "adding" mode
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

  /// Shown when no servers are configured. Offers direct type selection buttons
  /// so the user can immediately start connecting their first server.
  @ViewBuilder
  private var emptyStateSection: some View {
    ThemedSection {
      Button {
        handleAddServer(type: .jellyfin)
      } label: {
        Label {
          Text("Jellyfin")
            .foregroundStyle(theme.primaryColor)
        } icon: {
          Image(.jellyfinIcon)
        }
      }
      Button {
        handleAddServer(type: .audiobookshelf)
      } label: {
        Label {
          Text("AudiobookShelf")
            .foregroundStyle(theme.primaryColor)
        } icon: {
          Image(.audiobookshelfIcon)
        }
      }
    } header: {
      Text("media_servers_add_prompt".localized)
        .foregroundStyle(theme.secondaryColor)
    }
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
                .font(.caption)
                .foregroundStyle(theme.secondaryColor)
            }
            Spacer()
            Image(systemName: "chevron.right")
              .font(.caption)
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

  /// Activates the selected server in its connection service and navigates
  /// to the appropriate library browser (Jellyfin or AudiobookShelf root view).
  private func selectServer(_ server: ServerItem) {
    switch server.type {
    case .jellyfin:
      jellyfinService.activateConnection(id: server.id)
      listState.activeIntegrationSheet = .jellyfin
    case .audiobookshelf:
      audiobookshelfService.activateConnection(id: server.id)
      listState.activeIntegrationSheet = .audiobookshelf
    }
  }

  /// Routes the "add server" action based on whether the chosen type
  /// already has saved connections.
  ///
  /// - No existing connections of that type: navigates directly to the root view,
  ///   which will show its built-in connection form.
  /// - Existing connections: opens an in-place add-server sheet so the root view
  ///   doesn't try to load the existing server's library.
  private func handleAddServer(type: ServerType) {
    switch type {
    case .jellyfin:
      if jellyfinService.connections.isEmpty {
        listState.activeIntegrationSheet = .jellyfin
      } else {
        addingJellyfin = true
      }
    case .audiobookshelf:
      if audiobookshelfService.connections.isEmpty {
        listState.activeIntegrationSheet = .audiobookshelf
      } else {
        addingAudiobookshelf = true
      }
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
