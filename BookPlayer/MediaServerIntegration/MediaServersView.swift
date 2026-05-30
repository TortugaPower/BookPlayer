//
//  MediaServersView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/26/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

/// Unified entry-point screen for media-server integrations.
/// Two sections (Jellyfin / AudiobookShelf), per-section `[+]` button to add a
/// new server, per-row `(i)` button for server details, Edit mode + swipe-to-delete
/// for removal. Tapping a row activates that server and opens its library.
struct MediaServersView: View {
  let jellyfinService: JellyfinConnectionService
  let audiobookshelfService: AudiobookShelfConnectionService

  @State private var presentedAddServer: IntegrationKind?
  @State private var presentedLibrary: IntegrationKind?
  @State private var presentedConnectionDetails: ConnectionDetailsRoute?
  @State private var editMode: EditMode = .inactive

  @EnvironmentObject private var theme: ThemeViewModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Form {
        section(
          title: "Jellyfin",
          kind: .jellyfin,
          servers: jellyfinService.connections.map(ServerRow.init)
        )
        section(
          title: "AudiobookShelf",
          kind: .audiobookshelf,
          servers: audiobookshelfService.connections.map(ServerRow.init)
        )
      }
      .applyListStyle(with: theme, background: theme.systemBackgroundColor)
      .navigationTitle("media_servers_title".localized)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button { dismiss() } label: {
            Image(systemName: "xmark")
              .foregroundStyle(theme.linkColor)
          }
        }
        ToolbarItem(placement: .primaryAction) {
          EditButton()
            .foregroundStyle(theme.linkColor)
        }
      }
      .environment(\.editMode, $editMode)
    }
    .tint(theme.linkColor)
    .environmentObject(theme)
    .sheet(item: $presentedAddServer) { kind in
      addServerSheet(for: kind)
    }
    .sheet(item: $presentedLibrary) { kind in
      librarySheet(for: kind)
    }
    .sheet(item: $presentedConnectionDetails) { route in
      connectionDetailsSheet(for: route)
    }
  }

  // MARK: - Section builder

  @ViewBuilder
  private func section(title: String, kind: IntegrationKind, servers: [ServerRow]) -> some View {
    ThemedSection {
      ForEach(servers) { server in
        rowView(server, kind: kind)
      }
      .onDelete { indexSet in
        for index in indexSet {
          delete(servers[index], kind: kind)
        }
      }
    } header: {
      HStack {
        Text(title)
          .foregroundStyle(theme.secondaryColor)
        Spacer()
        Button {
          presentedAddServer = kind
        } label: {
          Image(systemName: "plus")
            .foregroundStyle(theme.linkColor)
        }
        .accessibilityLabel("integration_add_server_button".localized)
      }
    }
  }

  @ViewBuilder
  private func rowView(_ server: ServerRow, kind: IntegrationKind) -> some View {
    HStack {
      Button {
        select(server, kind: kind)
      } label: {
        VStack(alignment: .leading, spacing: 2) {
          Text(server.serverName)
            .foregroundStyle(theme.primaryColor)
          Text(server.userName)
            .font(.caption)
            .foregroundStyle(theme.secondaryColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      Button {
        // Show Connection Details scoped to THIS server (without activating it,
        // so the user's current active connection isn't changed by tapping info).
        presentedConnectionDetails = ConnectionDetailsRoute(connectionId: server.id, kind: kind)
      } label: {
        Image(systemName: "info.circle")
          .imageScale(.large)
          .foregroundStyle(theme.linkColor)
      }
      .buttonStyle(.borderless)
      .accessibilityHidden(true)
    }
    .swipeActions(edge: .trailing) {
      Button(role: .destructive) {
        delete(server, kind: kind)
      } label: {
        Label("logout_title".localized, systemImage: "trash")
      }
    }
    // VoiceOver merges the row's main button + trailing `(i)` button into a single
    // element, hiding the info action. Surface it explicitly via the actions rotor.
    .accessibilityAction(named: Text("integration_connection_details_title".localized)) {
      presentedConnectionDetails = ConnectionDetailsRoute(connectionId: server.id, kind: kind)
    }
  }

  // MARK: - Actions

  private func select(_ server: ServerRow, kind: IntegrationKind) {
    switch kind {
    case .jellyfin:
      jellyfinService.activateConnection(id: server.id)
    case .audiobookshelf:
      audiobookshelfService.activateConnection(id: server.id)
    }
    presentedLibrary = kind
  }

  private func delete(_ server: ServerRow, kind: IntegrationKind) {
    switch kind {
    case .jellyfin:
      jellyfinService.deleteConnection(id: server.id)
    case .audiobookshelf:
      audiobookshelfService.deleteConnection(id: server.id)
    }
  }

  // MARK: - Sheets

  @ViewBuilder
  private func addServerSheet(for kind: IntegrationKind) -> some View {
    switch kind {
    case .jellyfin:
      AddServerJellyfinSheet(connectionService: jellyfinService)
        .environmentObject(theme)
    case .audiobookshelf:
      AddServerAudiobookShelfSheet(connectionService: audiobookshelfService)
        .environmentObject(theme)
    }
  }

  @ViewBuilder
  private func librarySheet(for kind: IntegrationKind) -> some View {
    switch kind {
    case .jellyfin:
      JellyfinRootView(connectionService: jellyfinService)
    case .audiobookshelf:
      AudiobookShelfRootView(connectionService: audiobookshelfService)
    }
  }

  @ViewBuilder
  private func connectionDetailsSheet(for route: ConnectionDetailsRoute) -> some View {
    switch route.kind {
    case .jellyfin:
      ConnectionDetailsJellyfinSheet(
        connectionService: jellyfinService,
        connectionId: route.connectionId
      )
      .environmentObject(theme)
    case .audiobookshelf:
      ConnectionDetailsAudiobookShelfSheet(
        connectionService: audiobookshelfService,
        connectionId: route.connectionId
      )
      .environmentObject(theme)
    }
  }
}

private struct ConnectionDetailsRoute: Identifiable {
  let connectionId: String
  let kind: IntegrationKind
  var id: String { "\(kind.rawValue)-\(connectionId)" }
}

// MARK: - Helper types

enum IntegrationKind: String, Identifiable {
  case jellyfin
  case audiobookshelf
  var id: String { rawValue }
}

private struct ServerRow: Identifiable {
  let id: String
  let serverName: String
  let serverUrl: String
  let userName: String
  let customHeaders: [String: String]

  init(_ data: JellyfinConnectionData) {
    self.id = data.id
    self.serverName = data.serverName
    self.serverUrl = data.url.absoluteString
    self.userName = data.userName
    self.customHeaders = data.customHeaders
  }

  init(_ data: AudiobookShelfConnectionData) {
    self.id = data.id
    self.serverName = data.serverName
    self.serverUrl = data.url.absoluteString
    self.userName = data.userName
    self.customHeaders = data.customHeaders
  }
}


// MARK: - Add Server sheets
// Each wraps `IntegrationConnectionView` with a fresh VM constructed in `.addServer` mode,
// so its in-flight state is fully isolated from the active library session.

private struct AddServerJellyfinSheet: View {
  let connectionService: JellyfinConnectionService
  @StateObject private var viewModel: JellyfinConnectionViewModel
  @EnvironmentObject private var theme: ThemeViewModel
  @Environment(\.dismiss) private var dismiss

  init(connectionService: JellyfinConnectionService) {
    self.connectionService = connectionService
    self._viewModel = .init(
      wrappedValue: JellyfinConnectionViewModel(
        connectionService: connectionService,
        mode: .addServer
      )
    )
  }

  var body: some View {
    NavigationStack {
      IntegrationConnectionView(viewModel: viewModel, integrationName: "Jellyfin")
        .navigationBarTitleDisplayMode(.inline)
    }
    .tint(theme.linkColor)
    .environmentObject(theme)
    .onChange(of: viewModel.signInCompletedAt) { _, newValue in
      if newValue != nil { dismiss() }
    }
  }
}

private struct AddServerAudiobookShelfSheet: View {
  let connectionService: AudiobookShelfConnectionService
  @StateObject private var viewModel: AudiobookShelfConnectionViewModel
  @EnvironmentObject private var theme: ThemeViewModel
  @Environment(\.dismiss) private var dismiss

  init(connectionService: AudiobookShelfConnectionService) {
    self.connectionService = connectionService
    self._viewModel = .init(
      wrappedValue: AudiobookShelfConnectionViewModel(
        connectionService: connectionService,
        mode: .addServer
      )
    )
  }

  var body: some View {
    NavigationStack {
      IntegrationConnectionView(viewModel: viewModel, integrationName: "AudiobookShelf")
        .navigationBarTitleDisplayMode(.inline)
    }
    .tint(theme.linkColor)
    .environmentObject(theme)
    .onChange(of: viewModel.signInCompletedAt) { _, newValue in
      if newValue != nil { dismiss() }
    }
  }
}

// MARK: - Connection details sheets (per-server, scoped via `connectionId`)
// Reuses `IntegrationConnectionView`'s saved-list rendering (signInFlow == nil),
// but the VM is initialized with a specific `connectionId` so the form data and
// the destructive actions (logout, customHeaders update) target THAT server
// rather than the service's active connection.

private struct ConnectionDetailsJellyfinSheet: View {
  let connectionService: JellyfinConnectionService
  @StateObject private var viewModel: JellyfinConnectionViewModel
  @EnvironmentObject private var theme: ThemeViewModel
  @Environment(\.dismiss) private var dismiss

  init(connectionService: JellyfinConnectionService, connectionId: String) {
    self.connectionService = connectionService
    self._viewModel = .init(
      wrappedValue: JellyfinConnectionViewModel(
        connectionService: connectionService,
        mode: .viewDetails,
        connectionId: connectionId
      )
    )
  }

  var body: some View {
    NavigationStack {
      IntegrationConnectionView(viewModel: viewModel, integrationName: "Jellyfin")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button("done_title".localized) { dismiss() }
              .foregroundStyle(theme.linkColor)
          }
        }
    }
    .tint(theme.linkColor)
    .environmentObject(theme)
  }
}

private struct ConnectionDetailsAudiobookShelfSheet: View {
  let connectionService: AudiobookShelfConnectionService
  @StateObject private var viewModel: AudiobookShelfConnectionViewModel
  @EnvironmentObject private var theme: ThemeViewModel
  @Environment(\.dismiss) private var dismiss

  init(connectionService: AudiobookShelfConnectionService, connectionId: String) {
    self.connectionService = connectionService
    self._viewModel = .init(
      wrappedValue: AudiobookShelfConnectionViewModel(
        connectionService: connectionService,
        mode: .viewDetails,
        connectionId: connectionId
      )
    )
  }

  var body: some View {
    NavigationStack {
      IntegrationConnectionView(viewModel: viewModel, integrationName: "AudiobookShelf")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button("done_title".localized) { dismiss() }
              .foregroundStyle(theme.linkColor)
          }
        }
    }
    .tint(theme.linkColor)
    .environmentObject(theme)
  }
}
