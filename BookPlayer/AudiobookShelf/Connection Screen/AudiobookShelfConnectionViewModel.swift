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
  @Published var signInFlow: SignInStep?
  @Published private(set) var signInCompletedAt: Date?
  @Published var isAddingServer: Bool = false

  private var disposeBag = Set<AnyCancellable>()

  /// When non-nil, the VM operates on this specific connection (read its data on init,
  /// route logout / custom-headers updates to its id) regardless of which connection is
  /// active in the service. Used by `MediaServersView`'s per-server info sheet so editing
  /// one server doesn't change the active connection.
  let targetConnectionId: String?

  /// URL captured at `handleConnectAction` time, after normalization and a successful
  /// `pingServer`. `handleSignInAction` uses this rather than `form.serverUrl` so that
  /// any edit the user makes to the form between Connect and Sign In can't redirect the
  /// credentials to a server we never validated. Mirrors Jellyfin's `pendingServer`.
  private var pingedURL: String?

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
    connectionService: AudiobookShelfConnectionService,
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
    let normalizedURL = Self.normalizedServerURL(form.serverUrl)
    // Reflect the normalization back into the form so the user sees what we actually used.
    if normalizedURL != form.serverUrl {
      form.serverUrl = normalizedURL
    }
    let serverName = try await connectionService.pingServer(
      at: normalizedURL,
      customHeaders: form.customHeadersDictionary()
    )
    pingedURL = normalizedURL
    signInFlow = .enteringCredentials
    form.serverName = serverName
  }

  @MainActor
  func handleSignInAction() async throws {
    guard let serverUrl = pingedURL else {
      throw IntegrationError.urlMalformed(nil)
    }
    // Drop the captured URL after this method runs — on success the connection is
    // persisted, on failure the user must re-validate via Connect anyway.
    defer { pingedURL = nil }
    do {
      // ABS auth doesn't trim whitespace server-side, so iOS autocorrect inserting a trailing
      // space on the username is enough to silently reject otherwise-correct credentials.
      let username = form.username.trimmingCharacters(in: .whitespacesAndNewlines)
      let password = form.password.trimmingCharacters(in: .whitespacesAndNewlines)
      try await connectionService.signIn(
        username: username,
        password: password,
        serverUrl: serverUrl,
        serverName: form.serverName,
        customHeaders: form.customHeadersDictionary()
      )

      isAddingServer = false

      if let data = connectionService.connection {
        form.setValues(url: data.url.absoluteString, serverName: data.serverName, userName: data.userName)
      }
      signInFlow = nil
      signInCompletedAt = Date()
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
    // Drop any URL captured from a half-finished Connect → Sign In flow so a stale
    // value can't get reused by a later sign-in attempt.
    pingedURL = nil
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
