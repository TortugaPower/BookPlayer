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

/// What the alternative-sign-in slot on the credentials step renders, when the validated server
/// offers a way in besides typing a password.
///
/// One value instead of parallel `oidcSupported`/`quickConnectSupported` booleans: the slot shows at
/// most one thing, and a single optional makes the invalid "both at once" state unrepresentable. The
/// upcoming method-choice screen consumes exactly this value to decide which buttons exist.
enum AlternativeSignInState: Equatable {
  /// Native SSO through the server's identity provider (AudiobookShelf OIDC). The associated text is
  /// the provider's own button label when the server supplied one; nil falls back to a generic string.
  case oidc(buttonText: String?)

  /// The server advertises SSO but the connection is plaintext, so we refuse to run it — the
  /// authorization code, PKCE verifier, and returned token all traverse the redirect chain
  /// (RFC 6749 §10.9). Rendered as an explanation, not a button, so the absence isn't silent.
  case oidcRequiresSecureTransport

  /// Out-of-band code flow (Jellyfin Quick Connect).
  case quickConnect

  /// Whether the state offers something the user can actually start. Drives the username-field
  /// autofocus: an explanation-only state must not suppress the keyboard the way a real
  /// alternative does.
  var isActionable: Bool {
    switch self {
    case .oidc, .quickConnect:
      return true
    case .oidcRequiresSecureTransport:
      return false
    }
  }
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

  // MARK: - Alternative sign-in

  /// What the alternative-sign-in slot offers for the server the user just validated — not merely
  /// what the integration speaks. Nil when password is the only way in. Default: nil; concrete VMs
  /// opt in (AudiobookShelf → `.oidc`/`.oidcRequiresSecureTransport`, Jellyfin → `.quickConnect`).
  var alternativeSignIn: AlternativeSignInState? { get }

  /// Current state of an in-flight Quick Connect flow, or `nil` if none is running. Stays a separate
  /// member rather than riding in `alternativeSignIn`: it is render state for the Quick Connect
  /// sheet, mutating several times per flow, while `alternativeSignIn` is availability that holds
  /// still once Connect has probed the server.
  var quickConnectStatus: QuickConnectStatus? { get }

  /// Begin whichever flow `alternativeSignIn` advertises. Throws on setup failure; user cancellation
  /// surfaces as `CancellationError` so the host view can stay quiet.
  func handleStartAlternativeSignIn() async throws

  /// Cancel an in-flight alternative sign-in, dismiss any failure status, and free any underlying
  /// poller. Safe to call when no flow is running.
  func handleCancelAlternativeSignIn()
}

/// No-op defaults, so an integration without an alternative sign-in implements none of it.
extension IntegrationConnectionViewModelProtocol {
  var alternativeSignIn: AlternativeSignInState? { nil }
  var quickConnectStatus: QuickConnectStatus? { nil }
  func handleStartAlternativeSignIn() async throws {}
  func handleCancelAlternativeSignIn() {}
}
