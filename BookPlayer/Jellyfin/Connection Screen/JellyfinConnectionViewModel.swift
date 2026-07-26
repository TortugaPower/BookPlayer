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

    // `.receive(on:)` already delivers on the main queue, and this type is `@MainActor`, so no extra
    // `Task { @MainActor in }` hop is needed — one used to sit here and only widened the window in
    // which the replayed initial value could be observed.
    quickConnectStateSubscription = manager.$state
      .receive(on: DispatchQueue.main)
      .sink { [weak self] state in
        self?.handleQuickConnectStateChange(state)
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
  /// `internal` rather than `private` so `JellyfinQuickConnectTests` can drive the state table
  /// directly — `@testable` doesn't reach `private`, and the `.idle` case below is a regression worth
  /// pinning.
  @MainActor
  func handleQuickConnectStateChange(_ state: JellyfinAPI.QuickConnect.State) {
    switch state {
    case .idle:
      // Deliberately ignored. `QuickConnect.state` starts at `.idle` and `@Published` replays its
      // current value to every new subscriber, so this arrives once right after we subscribe — which,
      // if it were mapped to `quickConnectStatus = nil`, would tear down the sheet a hop after
      // presenting it AND leave `activeQuickConnect` set, so re-tapping the row became a silent no-op
      // with an invisible poller still running for its full ~16-minute budget.
      //
      // Nothing is lost by ignoring it: the only other source of `.idle` is `stop()`, and
      // `handleCancelQuickConnect` cancels this subscription on the very next line, so that emission
      // is never delivered either.
      break
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
      Self.logger.error("Quick Connect failed: \(String(describing: qcError))")
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
      Self.logger.error("Quick Connect sign-in failed: \(String(describing: error))")
      // Keep `pendingServer` so the user can retry or fall back to password without re-pinging.
      quickConnectStatus = .failed(Self.presentableMessage(for: error))
      teardownQuickConnect()
    }
  }

  /// Turns a sign-in failure into something worth showing a user.
  ///
  /// `Get.APIError.unacceptableStatusCode` documents its own description as a *debug* string — it reads
  /// "Response status code was unacceptable: 401." — so surfacing `localizedDescription` directly puts
  /// developer text in the UI. `handleSignInAction` already maps this onto `IntegrationError`, and Quick
  /// Connect should read identically for the same server response.
  private static func presentableMessage(for error: Error) -> String {
    if case APIError.unacceptableStatusCode(let statusCode) = error {
      let mapped: IntegrationError = (400...499).contains(statusCode)
        ? .clientError(code: statusCode)
        : .unexpectedResponse(code: statusCode)
      return mapped.localizedDescription
    }
    return error.localizedDescription
  }

  /// Drops the active controller + state subscription. Leaves `quickConnectStatus` untouched so
  /// callers decide whether the sheet dismisses (status = nil) or shows a terminal error.
  ///
  /// `stop()` is called unconditionally rather than only from `handleCancelQuickConnect`. Releasing our
  /// reference is NOT enough to end a poll: `QuickConnect` holds itself alive through
  /// `mainTask = Task { await run() }` and has no `deinit`, so an unstopped controller keeps polling for
  /// its full `maxPolls` budget (~16 minutes) with nobody listening. It happens to be harmless on the
  /// paths that reach here today — `run()` returns after `.authenticated` or `.error`, so the task is
  /// already finished — but making teardown unconditionally safe means no future caller has to re-derive
  /// that. `stop()` is idempotent, and the `.idle` it publishes is both ignored and undeliverable once
  /// the subscription below is cancelled.
  @MainActor
  private func teardownQuickConnect() {
    activeQuickConnect?.stop()
    activeQuickConnect = nil
    quickConnectStateSubscription?.cancel()
    quickConnectStateSubscription = nil
  }

  /// Translates the JellyfinAPI helper's error cases into a user-presentable, localizable message.
  ///
  /// `internal` rather than `private` so `JellyfinQuickConnectTests` can pin the whole table —
  /// `@testable` doesn't reach `private`.
  static func message(for error: JellyfinAPI.QuickConnect.QuickConnectError) -> String {
    switch error {
    case .maxPollingHit:
      return "jellyfin_quick_connect_error_timeout".localized
    case .retrievingCodeFailed:
      return "jellyfin_quick_connect_error_no_code".localized
    case .other:
      // Deliberately NOT returning the associated value. The SDK builds `.other` as
      // `.other(error.localizedDescription)` from whatever `client.send` threw, which for a non-2xx is
      // `Get.APIError`'s debug text ("Response status code was unacceptable: 401.") — not something to
      // show a user. The raw payload is logged by the caller instead.
      return "jellyfin_quick_connect_error_generic".localized
    }
  }
}
