//
//  AudiobookShelfConnectionViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/14/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import SwiftUI

@MainActor
final class AudiobookShelfConnectionViewModel: IntegrationConnectionViewModelProtocol, BPLogger {
  let connectionService: AudiobookShelfConnectionService

  @Published var form: IntegrationConnectionFormViewModel
  @Published var viewMode: IntegrationViewMode = .regular
  @Published var connectionState: IntegrationConnectionState
  @Published var isAddingServer: Bool = false

  private var disposeBag = Set<AnyCancellable>()

  var servers: [IntegrationServerInfo] {
    connectionService.connections.map { data in
      IntegrationServerInfo(
        id: data.id,
        serverName: data.serverName,
        serverUrl: data.url.absoluteString,
        userName: data.userName,
        isActive: data.id == connectionService.connection?.id
      )
    }
  }

  init(
    connectionService: AudiobookShelfConnectionService,
    mode: IntegrationViewMode = .regular
  ) {
    self.connectionService = connectionService
    self._viewMode = .init(initialValue: mode)
    let form = IntegrationConnectionFormViewModel()

    if let data = connectionService.connection {
      form.setValues(
        url: data.url.absoluteString,
        serverName: data.serverName,
        userName: data.userName,
        customHeaders: data.customHeaders
      )
      self._connectionState = .init(initialValue: .connected)
    } else {
      self._connectionState = .init(initialValue: .disconnected)
    }

    self._form = .init(initialValue: form)
  }

  @MainActor
  func handleConnectAction() async throws {
    let normalizedURL = Self.normalizedServerURL(form.serverUrl)
    // Reflect the normalization back into the form so the user sees what we actually used.
    if normalizedURL != form.serverUrl {
      form.serverUrl = normalizedURL
    }
    let serverName = try await connectionService.pingServer(
      at: normalizedURL,
      customHeaders: form.customHeadersDictionary()
    )
    connectionState = .foundServer
    form.serverName = serverName
  }

  @MainActor
  func handleSignInAction() async throws {
    do {
      let wasAdding = isAddingServer
      // ABS auth doesn't trim whitespace server-side, so iOS autocorrect inserting a trailing
      // space on the username is enough to silently reject otherwise-correct credentials.
      let username = form.username.trimmingCharacters(in: .whitespacesAndNewlines)
      let password = form.password.trimmingCharacters(in: .whitespacesAndNewlines)
      try await connectionService.signIn(
        username: username,
        password: password,
        serverUrl: form.serverUrl,
        serverName: form.serverName,
        customHeaders: form.customHeadersDictionary()
      )

      if wasAdding {
        isAddingServer = false
      }

      if let data = connectionService.connection {
        form.setValues(url: data.url.absoluteString, serverName: data.serverName, userName: data.userName)
      }
      connectionState = .connected
    } catch let error as IntegrationError {
      throw error
    } catch {
      throw error
    }
  }

  /// Normalize the user-typed server URL before we send a request:
  ///   - Trim whitespace.
  ///   - Prepend `https://` if no scheme is present, so `URL(string:)` parses it as an absolute
  ///     URL rather than a relative path. Without this, "abs.example.com" becomes a URL with
  ///     a nil host and the eventual /ping POST fails with an opaque URLError.
  static func normalizedServerURL(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return trimmed }
    let lowered = trimmed.lowercased()
    if lowered.hasPrefix("http://") || lowered.hasPrefix("https://") {
      return trimmed
    }
    return "https://" + trimmed
  }

  @MainActor
  func handleSignOutAction() {
    connectionService.deleteConnection()
    form = IntegrationConnectionFormViewModel()
    connectionState = connectionService.connections.isEmpty ? .disconnected : .connected
    if let data = connectionService.connection {
      form.setValues(url: data.url.absoluteString, serverName: data.serverName, userName: data.userName)
    }
  }

  func handleSignOutAction(id: String) {
    connectionService.deleteConnection(id: id)
    if connectionService.connections.isEmpty {
      form = IntegrationConnectionFormViewModel()
      connectionState = .disconnected
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
    form = IntegrationConnectionFormViewModel()
  }

  func handleCancelAddServerAction() {
    isAddingServer = false
    if let data = connectionService.connection {
      form.setValues(url: data.url.absoluteString, serverName: data.serverName, userName: data.userName)
    }
    connectionState = .connected
  }

  @MainActor
  func handleCustomHeadersUpdate() {
    connectionService.updateCustomHeaders(form.customHeadersDictionary())
  }
}
