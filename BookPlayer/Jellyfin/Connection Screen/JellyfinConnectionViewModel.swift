//
//  JellyfinConnectionViewModel.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-10-25.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import JellyfinAPI
import SwiftUI

class JellyfinConnectionViewModel: ViewModelProtocol, ObservableObject {
  enum Routes {
    case cancel
    case signInFinished(userID: String, client: JellyfinClient)
    case signOut
    case showLibrary
  }

  enum ConnectionState {
    case disconnected
    case foundServer
    case connected
  }


  weak var coordinator: JellyfinCoordinator!

  @Published var form: JellyfinConnectionFormViewModel = JellyfinConnectionFormViewModel()
  @Published var connectionState: ConnectionState = .disconnected

  public var onTransition: BPTransition<Routes>?


  func loadConnectionData(from data: JellyfinConnectionData?) {
    reset()
    
    if let data {
      form.serverUrl = data.url.absoluteString
      form.serverName = data.serverName
      form.username = data.userName
      //form.password is not saved (we have an access token instead). Leave the field blank.
      form.rememberMe = true
      connectionState = .connected
    }
  }
  
  private func reset() {
    form = JellyfinConnectionFormViewModel()
    connectionState = .disconnected
  }


  func handleCancelAction() {
    onTransition?(.cancel)
  }
  
  func handleConnectedEvent(userID: String, client: JellyfinClient) {
    onTransition?(.signInFinished(userID: userID, client: client))
  }

  func handleSignOutAction() {
    onTransition?(.signOut)
  }

  func handleToToLibraryAction() {
    onTransition?(.showLibrary)
  }
}
