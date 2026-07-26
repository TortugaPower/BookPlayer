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

  /// What the validated server reported it supports. Probed in `handleConnectAction` rather than
  /// assumed: AudiobookShelf-the-product speaks OIDC, but an individual server only offers it once an
  /// admin has configured a provider, so a hardcoded `true` would show most users a button that
  /// cannot possibly work.
  @Published private(set) var capabilities = AudiobookShelfConnectionService.ServerCapabilities()

  var oidcSupported: Bool { capabilities.supportsOIDC && isPingedURLSecure }

  var oidcButtonText: String? { capabilities.oidcButtonText }

  var oidcBlockedByInsecureTransport: Bool {
    capabilities.supportsOIDC && !isPingedURLSecure
  }

  /// SSO is refused over plaintext: the authorization code, the PKCE verifier and the returned token
  /// all traverse the redirect chain (RFC 6749 §10.9). Password sign-in over http stays the user's
  /// own call.
  private var isPingedURLSecure: Bool {
    guard let pingedURL, let scheme = URL(string: pingedURL)?.scheme else { return false }
    return scheme.lowercased() == "https"
  }

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
    // Ask the server which sign-in methods it actually offers before showing the credentials step.
    // Non-throwing by design — an unavailable probe just means no SSO button.
    capabilities = await connectionService.fetchCapabilities(
      at: normalizedURL,
      customHeaders: form.customHeadersDictionary()
    )
    signInFlow = .enteringCredentials
    form.serverName = serverName
  }

  @MainActor
  func handleSignInAction() async throws {
    guard let serverUrl = pingedURL else {
      throw IntegrationError.urlMalformed(nil)
    }
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

      // Drop the captured URL only once the connection is persisted. Clearing it on every
      // exit (an unconditional `defer`) stranded the user after a wrong password: the sheet
      // stays on the credentials step, so the retry hit the `guard` above and threw
      // `urlMalformed(nil)` instead of re-attempting sign-in. Keeping it across a failure
      // preserves the safety property — credentials still only go to the pinged URL, and a
      // form edit in between still can't redirect them.
      pingedURL = nil
      capabilities = .init()
      isAddingServer = false

      if let data = connectionService.connection {
        form.setValues(
          url: data.url.absoluteString,
          serverName: data.serverName,
          userName: data.userName,
          customHeaders: data.customHeaders
        )
      }
      signInFlow = nil
      signInCompletedAt = Date()
    } catch let error as IntegrationError {
      throw error
    } catch {
      throw error
    }
  }

  @MainActor
  func prepareReauth() {
    let data = targetConnectionId.flatMap { id in
      connectionService.connections.first(where: { $0.id == id })
    } ?? connectionService.connection

    if let data {
      form.setValues(
        url: data.url.absoluteString,
        serverName: data.serverName,
        userName: data.userName,
        customHeaders: data.customHeaders
      )
    }
    // Anything captured for a previous attempt is stale now.
    pingedURL = nil
    capabilities = .init()
    signInFlow = .enteringServerURL
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
      form.setValues(
        url: data.url.absoluteString,
        serverName: data.serverName,
        userName: data.userName,
        customHeaders: data.customHeaders
      )
    }
  }

  func handleSignOutAction(id: String) {
    connectionService.deleteConnection(id: id)
    if connectionService.connections.isEmpty {
      form = IntegrationConnectionFormViewModel()
      signInFlow = .enteringServerURL
    } else if let data = connectionService.connection {
      form.setValues(
        url: data.url.absoluteString,
        serverName: data.serverName,
        userName: data.userName,
        customHeaders: data.customHeaders
      )
    }
  }

  func handleActivateAction(id: String) {
    connectionService.activateConnection(id: id)
    if let data = connectionService.connection {
      form.setValues(
        url: data.url.absoluteString,
        serverName: data.serverName,
        userName: data.userName,
        customHeaders: data.customHeaders
      )
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
    capabilities = .init()
    if let data = connectionService.connection {
      form.setValues(
        url: data.url.absoluteString,
        serverName: data.serverName,
        userName: data.userName,
        customHeaders: data.customHeaders
      )
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

  // MARK: - SSO (OpenID Connect)

  /// Starts the native ABS OpenID Connect flow against the validated `pingedURL`, then
  /// transitions form/state to match a successful password sign-in. The system web-auth sheet
  /// drives the IdP handshake; on user cancellation the service throws `CancellationError`,
  /// which the shared view swallows.
  @MainActor
  func handleStartOIDC() async throws {
    guard let serverUrl = pingedURL else {
      throw IntegrationError.urlMalformed(nil)
    }
    try await connectionService.signInWithOIDC(
      serverUrl: serverUrl,
      serverName: form.serverName,
      customHeaders: form.customHeadersDictionary()
    )
    // Only drop the validated URL once sign-in succeeded.
    pingedURL = nil
    capabilities = .init()
    isAddingServer = false
    if let data = connectionService.connection {
      form.setValues(
        url: data.url.absoluteString,
        serverName: data.serverName,
        userName: data.userName,
        customHeaders: data.customHeaders
      )
    }
    signInFlow = nil
    signInCompletedAt = Date()
  }
}
