//
//  JellyfinConnectionViewModel.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-10-25.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import Get
import JellyfinAPI
import SwiftUI

@MainActor
final class JellyfinConnectionViewModel: IntegrationConnectionViewModelProtocol, BPLogger {
  let connectionService: JellyfinConnectionService

  @Published var form: IntegrationConnectionFormViewModel
  @Published var viewMode: IntegrationViewMode = .regular
  @Published var signInFlow: SignInStep?
  @Published private(set) var signInCompletedAt: Date?
  @Published var isAddingServer: Bool = false

  /// Current state of an in-flight Quick Connect flow, or `nil` if none is running. Mirrored
  /// to the shared `IntegrationConnectionView` via the protocol so it can render the
  /// awaiting-code overlay and react to failure/success.
  @Published var quickConnectStatus: QuickConnectStatus?

  /// Jellyfin exposes Quick Connect on every server build that implements `/QuickConnect/*`.
  /// The shared connection UI uses this to decide whether to surface the affordance.
  let quickConnectSupported: Bool = true

  /// Active Quick Connect controller, retained so its polling task isn't deallocated and so
  /// cancel/cleanup can call `stop()`. Nil when no flow is in progress.
  private var activeQuickConnect: JellyfinAPI.QuickConnect?

  /// Subscription to the Quick Connect helper's `state` publisher, dropped when the flow ends.
  private var quickConnectStateSubscription: AnyCancellable?

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

      // Drop the transient `pending` only once the service has committed it as
      // `self.client`. Clearing it on every exit (an unconditional `defer`) stranded the
      // user after a wrong password: the sheet stays on the credentials step, so the retry
      // hit the `guard` above and threw `noClient` instead of re-attempting sign-in.
      // `signIn(pending:)` only reads `pending.client` and commits nothing on failure, so
      // the validated client is still good for another attempt.
      pendingServer = nil
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
    // Drop any transient `pending` from a half-finished Connect → Sign In flow,
    // so a stale `JellyfinClient` can't get reused by a later sign-in attempt.
    pendingServer = nil
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
    // The transient client from any previous attempt is stale; Connect rebuilds it.
    pendingServer = nil
    signInFlow = .enteringServerURL
  }

  // MARK: - Quick Connect

  /// Starts the Jellyfin Quick Connect flow against the validated `pendingServer` client.
  ///
  /// Builds a controller, subscribes to its state publisher, then kicks the flow off. State
  /// transitions are handled in ``handleQuickConnectStateChange(_:)``. Throws synchronously
  /// only for setup failure (no validated server yet); mid-flight failures arrive async via
  /// the published state and surface as `quickConnectStatus = .failed(...)`.
  @MainActor
  func handleStartQuickConnect() async throws {
    // Idempotent: ignore if a flow is already in progress.
    guard activeQuickConnect == nil else { return }
    guard let pending = pendingServer else {
      throw IntegrationError.noClient("Jellyfin")
    }

    let manager = connectionService.makeQuickConnectController(using: pending.client)
    activeQuickConnect = manager
    quickConnectStatus = .retrievingCode

    quickConnectStateSubscription = manager.$state
      .receive(on: DispatchQueue.main)
      .sink { [weak self] state in
        guard let self else { return }
        Task { @MainActor in
          self.handleQuickConnectStateChange(state)
        }
      }

    manager.start()
  }

  /// Cancels an in-flight Quick Connect flow and clears any pending status. Safe to call when
  /// no flow is running.
  @MainActor
  func handleCancelQuickConnect() {
    activeQuickConnect?.stop()
    teardownQuickConnect()
    quickConnectStatus = nil
  }

  /// Maps JellyfinAPI's Quick Connect helper states to the protocol-level `QuickConnectStatus`
  /// and drives the final sign-in step on `.authenticated`.
  @MainActor
  private func handleQuickConnectStateChange(_ state: JellyfinAPI.QuickConnect.State) {
    switch state {
    case .idle:
      quickConnectStatus = nil
    case .retrievingCode:
      quickConnectStatus = .retrievingCode
    case .polling(let code):
      quickConnectStatus = .awaitingCode(code)
    case .authenticated(let secret):
      quickConnectStatus = .authenticating
      Task { @MainActor in
        await self.completeQuickConnectSignIn(secret: secret)
      }
    case .error(let qcError):
      Self.logger.error("Quick Connect failed: \(qcError.localizedDescription)")
      quickConnectStatus = .failed(Self.message(for: qcError))
      teardownQuickConnect()
    }
  }

  /// Exchanges the authorized Quick Connect secret for an access token via the connection
  /// service, then transitions form/state to look the same as a successful password sign-in.
  @MainActor
  private func completeQuickConnectSignIn(secret: String) async {
    guard let pending = pendingServer else {
      quickConnectStatus = .failed(IntegrationError.noClient("Jellyfin").localizedDescription)
      teardownQuickConnect()
      return
    }
    do {
      let userName = try await connectionService.signInWithQuickConnect(
        pending: pending,
        secret: secret,
        serverName: form.serverName,
        customHeaders: form.customHeadersDictionary()
      )
      // Only drop the transient pending handle once the service has committed it.
      pendingServer = nil
      isAddingServer = false
      if let data = connectionService.connection {
        form.setValues(
          url: data.url.absoluteString,
          serverName: data.serverName,
          userName: data.userName,
          // Must be passed: `IntegrationCustomHeadersSectionView` commits on `onDisappear`, so a form
          // left with an empty header list writes that emptiness over the saved connection when the
          // sheet closes. `setValues` has no default for this argument precisely to catch the omission.
          customHeaders: data.customHeaders
        )
      } else {
        form.username = userName
      }
      signInFlow = nil
      signInCompletedAt = Date()
      quickConnectStatus = nil
      teardownQuickConnect()
    } catch {
      Self.logger.error("Quick Connect sign-in failed: \(error.localizedDescription)")
      // Keep `pendingServer` so the user can retry or fall back to password without re-pinging.
      quickConnectStatus = .failed(error.localizedDescription)
      teardownQuickConnect()
    }
  }

  /// Drops the active controller + state subscription. Leaves `quickConnectStatus` untouched so
  /// callers decide whether the sheet dismisses (status = nil) or shows a terminal error.
  @MainActor
  private func teardownQuickConnect() {
    activeQuickConnect = nil
    quickConnectStateSubscription?.cancel()
    quickConnectStateSubscription = nil
  }

  /// Translates the JellyfinAPI helper's error cases into a user-presentable, localizable message.
  private static func message(for error: JellyfinAPI.QuickConnect.QuickConnectError) -> String {
    switch error {
    case .maxPollingHit:
      return "jellyfin_quick_connect_error_timeout".localized
    case .retrievingCodeFailed:
      return "jellyfin_quick_connect_error_no_code".localized
    case .other(let message):
      return message
    }
  }
}
