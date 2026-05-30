//
//  JellyfinConnectionViewModel.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-10-25.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Get
import SwiftUI

@MainActor
final class JellyfinConnectionViewModel: IntegrationConnectionViewModelProtocol, BPLogger {
  let connectionService: JellyfinConnectionService

  @Published var form: IntegrationConnectionFormViewModel
  @Published var viewMode: IntegrationViewMode = .regular
  @Published var signInFlow: SignInStep?
  @Published private(set) var signInCompletedAt: Date?
  @Published var isAddingServer: Bool = false

  /// Transient handle returned by `findServer`. Held across the connect → sign-in
  /// transition so the service can commit it without touching `self.client` mid-flight.
  private var pendingServer: JellyfinConnectionService.PendingServer?

  /// When non-nil, the VM operates on this specific connection (read its data on init,
  /// route logout / custom-headers updates to its id) regardless of which connection is
  /// active in the service. Used by `MediaServersView`'s per-server info sheet so editing
  /// one server doesn't change the active connection.
  let targetConnectionId: String?

  var servers: [IntegrationServerInfo] {
    connectionService.connections.map { data in
      IntegrationServerInfo(
        id: data.id,
        serverName: data.serverName,
        serverUrl: data.url.absoluteString,
        userName: data.userName
      )
    }
  }

  init(
    connectionService: JellyfinConnectionService,
    mode: IntegrationViewMode = .regular,
    connectionId: String? = nil
  ) {
    self.connectionService = connectionService
    self.targetConnectionId = connectionId
    self._viewMode = .init(initialValue: mode)
    let form = IntegrationConnectionFormViewModel()

    switch mode {
    case .addServer:
      // Dedicated Add Server flow: start clean, no pre-population from active connection.
      self._signInFlow = .init(initialValue: .enteringServerURL)
      self._isAddingServer = .init(initialValue: true)
    case .regular, .viewDetails:
      // If `connectionId` is provided, pull from that specific saved connection so this VM
      // can edit a non-active server. Otherwise fall back to whichever one is active.
      let data = connectionId.flatMap { id in
        connectionService.connections.first(where: { $0.id == id })
      } ?? connectionService.connection

      if let data {
        form.setValues(
          url: data.url.absoluteString,
          serverName: data.serverName,
          userName: data.userName,
          customHeaders: data.customHeaders
        )
        self._signInFlow = .init(initialValue: nil)
      } else {
        self._signInFlow = .init(initialValue: .enteringServerURL)
      }
    }

    self._form = .init(initialValue: form)
  }

  @MainActor
  func handleConnectAction() async throws {
    let pending = try await connectionService.findServer(
      at: form.serverUrl,
      customHeaders: form.customHeadersDictionary()
    )
    pendingServer = pending
    signInFlow = .enteringCredentials
    form.serverName = pending.serverName
  }

  @MainActor
  func handleSignInAction() async throws {
    guard let pending = pendingServer else {
      throw IntegrationError.noClient("Jellyfin")
    }
    do {
      try await connectionService.signIn(
        pending: pending,
        username: form.username,
        password: form.password,
        serverName: form.serverName,
        customHeaders: form.customHeadersDictionary()
      )

      isAddingServer = false
      pendingServer = nil

      if let data = connectionService.connection {
        form.setValues(url: data.url.absoluteString, serverName: data.serverName, userName: data.userName)
      }
      signInFlow = nil
      signInCompletedAt = Date()
    } catch APIError.unacceptableStatusCode(let statusCode) {
      switch statusCode {
      case 400...499:
        throw IntegrationError.clientError(code: statusCode)
      default:
        throw IntegrationError.unexpectedResponse(code: statusCode)
      }
    } catch {
      throw error
    }
  }

  @MainActor
  func handleSignOutAction() {
    // If this VM was scoped to a specific connection, route the deletion there.
    // Otherwise act on the active one (the cog → Connection Details flow).
    if let targetId = targetConnectionId {
      connectionService.deleteConnection(id: targetId)
    } else {
      connectionService.deleteConnection()
    }
    form = IntegrationConnectionFormViewModel()
    signInFlow = connectionService.connections.isEmpty ? .enteringServerURL : nil
    if let data = connectionService.connection {
      form.setValues(url: data.url.absoluteString, serverName: data.serverName, userName: data.userName)
    }
  }

  func handleSignOutAction(id: String) {
    connectionService.deleteConnection(id: id)
    if connectionService.connections.isEmpty {
      form = IntegrationConnectionFormViewModel()
      signInFlow = .enteringServerURL
    } else if let data = connectionService.connection {
      form.setValues(url: data.url.absoluteString, serverName: data.serverName, userName: data.userName)
    }
  }

  func handleActivateAction(id: String) {
    connectionService.activateConnection(id: id)
    if let data = connectionService.connection {
      form.setValues(url: data.url.absoluteString, serverName: data.serverName, userName: data.userName)
    }
  }

  func handleAddServerAction() {
    isAddingServer = true
    signInFlow = .enteringServerURL
    form = IntegrationConnectionFormViewModel()
  }

  func handleCancelAddServerAction() {
    isAddingServer = false
    signInFlow = nil
    if let data = connectionService.connection {
      form.setValues(url: data.url.absoluteString, serverName: data.serverName, userName: data.userName)
    }
  }

  @MainActor
  func handleCustomHeadersUpdate() {
    let headers = form.customHeadersDictionary()
    if let targetId = targetConnectionId {
      connectionService.updateCustomHeaders(id: targetId, headers)
    } else {
      connectionService.updateCustomHeaders(headers)
    }
  }
}
