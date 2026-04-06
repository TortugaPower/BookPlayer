//
//  IntegrationConnectionViewModelProtocol.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/5/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

enum IntegrationConnectionState {
  case disconnected
  case foundServer
  case connected
}

enum IntegrationViewMode {
  case regular
  case viewDetails
}

struct IntegrationServerInfo: Identifiable {
  let id: String
  let serverName: String
  let serverUrl: String
  let userName: String
  let isActive: Bool
}

@MainActor
protocol IntegrationConnectionViewModelProtocol: ObservableObject {
  associatedtype FormVM: IntegrationConnectionFormViewModelProtocol

  var form: FormVM { get set }
  var viewMode: IntegrationViewMode { get set }
  var connectionState: IntegrationConnectionState { get set }

  /// All saved server connections
  var servers: [IntegrationServerInfo] { get }

  /// Whether the user is adding a new server from the settings screen
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
}
