//
//  IntegrationConnectionViewModelProtocol.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/5/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

/// Current step of the sign-in flow. `nil` means the user is not actively
/// signing in — the view should show the connection-details UI for the
/// active connection (server info + custom headers + logout). Multi-server
/// management lives in `MediaServersView`, not here.
enum SignInStep {
  /// User is entering the server URL (initial step).
  case enteringServerURL
  /// Server has been validated; user is entering credentials.
  case enteringCredentials
}

enum IntegrationViewMode {
  /// Bound to a live library session; pre-populates form from the active connection.
  case regular
  /// Cog → Connection Details flow; pre-populates form, shows connection-details UI.
  case viewDetails
  /// Dedicated Add Server flow; starts with empty form, no active-connection state leaks.
  case addServer
}

struct IntegrationServerInfo: Identifiable {
  let id: String
  let serverName: String
  let serverUrl: String
  let userName: String
}

/// Status of an out-of-band code-based authentication flow (Jellyfin Quick Connect).
///
/// The device asks the server for a short user-facing code, then polls until the user enters
/// that code in an already-authenticated session of the server's web UI. While the device is
/// waiting it sits in `.awaitingCode`; once the server marks the request authorized, the device
/// enters `.authenticating` while it exchanges the secret for an access token. Failures are
/// surfaced as `.failed`, with a localized message ready for display.
enum QuickConnectStatus: Equatable {
  /// The client has called the server's `/QuickConnect/Initiate` endpoint and is waiting for
  /// the user-facing code to come back. Briefly visible while the network round-trip completes.
  case retrievingCode

  /// The server returned a short code and the client is polling. The user must enter this code
  /// on the server's web UI (User menu → Quick Connect) to authorize the device.
  case awaitingCode(String)

  /// The user authorized the request. The client is exchanging the secret for an access token.
  case authenticating

  /// The flow ended in a failure. The associated value is a user-presentable message.
  case failed(String)
}

@MainActor
protocol IntegrationConnectionViewModelProtocol: ObservableObject {
  associatedtype FormVM: IntegrationConnectionFormViewModelProtocol

  var form: FormVM { get set }
  var viewMode: IntegrationViewMode { get set }

  /// Drives what the view renders.
  /// `.enteringServerURL` → URL form; `.enteringCredentials` → credentials form; `nil` → connection-details UI.
  var signInFlow: SignInStep? { get set }

  /// Timestamp of the last successful sign-in. Observers use this as a signal
  /// to react to real sign-in completions (distinct from cancellations).
  var signInCompletedAt: Date? { get }

  /// All saved server connections
  var servers: [IntegrationServerInfo] { get }

  /// Whether the user is adding a new server from the settings screen
  /// (vs the initial-connect flow). Used by the toolbar to surface a Cancel
  /// button when adding from Settings.
  var isAddingServer: Bool { get set }

  func handleConnectAction() async throws
  func handleSignInAction() async throws
  func handleSignOutAction()

  /// Sign out a specific server by ID
  func handleSignOutAction(id: String)

  /// Switch active server
  func handleActivateAction(id: String)

  /// Begin adding a new server from settings
  func handleAddServerAction()

  /// Cancel adding a new server
  func handleCancelAddServerAction()

  /// Persist any changes made to the custom-headers list while the connection is already live.
  func handleCustomHeadersUpdate()

  /// Put the form into a state the user can actually re-authenticate from, seeded with the saved
  /// connection (URL, name, custom headers).
  ///
  /// The session-expired alert used to drop the user on the read-only connection-details screen, which
  /// offers no sign-in affordance at all — the only button there is Log out. Routing through the
  /// server-URL step instead means Connect re-validates the server and re-reads its capabilities, which
  /// is what restores both password sign-in (it needs a freshly validated URL) and the SSO button (it
  /// needs `/status`). Without that, an SSO-only user with no password has no way back in.
  func prepareReauth()

  // MARK: - Alternative sign-in methods
  //
  // Two independent, mutually exclusive in practice: AudiobookShelf opts into OIDC, Jellyfin into
  // Quick Connect, and each leaves the other at its default. The shared view renders whichever the
  // concrete view model advertises.

  /// Whether SSO can actually be used with the server the user just validated — not merely whether
  /// the integration speaks it. Default: `false`; concrete VMs opt in (AudiobookShelf).
  var oidcSupported: Bool { get }

  /// The provider's own button label, when the server supplied one. Falls back to a generic string.
  var oidcButtonText: String? { get }

  /// Set when the server advertises SSO but we refuse it because the connection is plaintext, so the
  /// UI can explain the absence rather than silently hiding an option the user may be expecting.
  var oidcBlockedByInsecureTransport: Bool { get }

  /// Begin the native SSO flow. Throws on setup failure; user cancellation surfaces as
  /// `CancellationError` so the host view can stay quiet.
  func handleStartOIDC() async throws

  /// Whether this integration supports an out-of-band code-based sign-in flow
  /// (Jellyfin's Quick Connect). Default: `false` — concrete VMs opt in.
  var quickConnectSupported: Bool { get }

  /// Current state of an in-flight Quick Connect flow, or `nil` if none is running.
  var quickConnectStatus: QuickConnectStatus? { get }

  /// Begin the Quick Connect flow. Throws if the underlying api-client cannot be reached.
  func handleStartQuickConnect() async throws

  /// Cancel an in-flight Quick Connect flow, dismiss any failure status, and free the
  /// underlying poller. Safe to call when no flow is running.
  func handleCancelQuickConnect()
}

/// No-op defaults for both alternative sign-in methods, so an integration only has to implement the
/// one it actually speaks.
extension IntegrationConnectionViewModelProtocol {
  var oidcSupported: Bool { false }
  var oidcButtonText: String? { nil }
  var oidcBlockedByInsecureTransport: Bool { false }
  func handleStartOIDC() async throws {}

  var quickConnectSupported: Bool { false }
  var quickConnectStatus: QuickConnectStatus? { nil }
  func handleStartQuickConnect() async throws {}
  func handleCancelQuickConnect() {}
}
