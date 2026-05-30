//
//  IntegrationConnectionViewModelProtocol.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/5/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

/// Current step of the sign-in flow. `nil` means the user is not actively
/// signing in — the view should show the saved-servers list.
enum SignInStep {
  /// User is entering the server URL (initial step).
  case enteringServerURL
  /// Server has been validated; user is entering credentials.
  case enteringCredentials
}

enum IntegrationViewMode {
  /// Bound to a live library session; pre-populates form from the active connection.
  case regular
  /// Cog → Connection Details flow; pre-populates form, shows saved-list view.
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

@MainActor
protocol IntegrationConnectionViewModelProtocol: ObservableObject {
  associatedtype FormVM: IntegrationConnectionFormViewModelProtocol

  var form: FormVM { get set }
  var viewMode: IntegrationViewMode { get set }

  /// Drives what the view renders.
  /// `.enteringServerURL` → URL form; `.enteringCredentials` → credentials form; `nil` → saved-servers list.
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
}
