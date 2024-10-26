//
//  JellyfinConnectionViewModel.swift
//  BookPlayer
//
//  Created by Lysann Schlegel on 2024-10-25.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import SwiftUI
import Combine
import JellyfinAPI

class JellyfinConnectionViewModel: ViewModelProtocol, ObservableObject {
  /// Possible routes for the screen
  enum Routes {
    case cancel
    case loginFinished(JellyfinClient)
  }

  enum ConnectionState {
    case disconnected
    case foundServer
    case connected
  }


  weak var coordinator: JellyfinCoordinator!

  var form: JellyfinConnectionFormViewModel = JellyfinConnectionFormViewModel()

  @Published var connectionState: ConnectionState = .disconnected


  /// Callback to handle actions on this screen
  public var onTransition: BPTransition<Routes>?

  func handleCancelAction() {
    onTransition?(.cancel)
  }

  func handleConnectedEvent(forClient client: JellyfinClient) {
    onTransition?(.loginFinished(client))
  }
}
