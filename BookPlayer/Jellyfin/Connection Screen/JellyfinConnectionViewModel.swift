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
  
  let jellyfinConnectionService: JellyfinConnectionService
  
  @Published var form: JellyfinConnectionFormViewModel = JellyfinConnectionFormViewModel()
  @Published var connectionState: ConnectionState = .disconnected
  
  public var onTransition: BPTransition<Routes>?
  
  private var disposeBag = Set<AnyCancellable>()
  
  
  init(jellyfinConnectionService: JellyfinConnectionService) {
    self.jellyfinConnectionService = jellyfinConnectionService
    bindObservers()
  }
  
  private func bindObservers() {
    jellyfinConnectionService.$connection
      .sink { [weak self] data in
        guard let self else {
          return
        }
        
        self.reset()
        
        if let data {
          self.form.serverUrl = data.url.absoluteString
          self.form.serverName = data.serverName
          self.form.username = data.userName
          //self.form.password is not saved (we have an access token instead). Leave the field blank.
          self.form.rememberMe = true
          self.connectionState = .connected
        }
      }
      .store(in: &disposeBag)
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
