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
  
  enum ViewMode {
    case regular // for the "Download from Jellyfin" flow
    case viewDetails // for the connection details + sign out option from the Settings screen
  }
  
  enum ConnectionState {
    case disconnected
    case foundServer
    case connected
  }
  
  
  weak var coordinator: JellyfinCoordinator!
  
  let jellyfinConnectionService: JellyfinConnectionService
  
  @Published var form: JellyfinConnectionFormViewModel = JellyfinConnectionFormViewModel()
  @Published var viewMode: ViewMode = .regular
  @Published var connectionState: ConnectionState = .disconnected
  @Published var apiTask: Task<(), any Error>?
  var canConnect: Bool {
    viewMode == .regular &&
    apiTask == nil &&
    connectionState == .disconnected &&
    !form.serverUrl.isEmpty
  }
  var canSignIn: Bool {
    viewMode == .regular &&
    apiTask == nil &&
    connectionState == .foundServer &&
    !form.serverUrl.isEmpty &&
    !form.username.isEmpty &&
    !form.password.isEmpty
  }
  var canGoToLibrary: Bool {
    viewMode == .regular &&
    connectionState == .connected
  }
  
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


  @MainActor
  func handleCancelAction() {
    onTransition?(.cancel)
  }
  
  @MainActor
  func handleConnectAction() {
    guard canConnect else {
      return
    }
    
    guard let apiClient = JellyfinConnectionService.createClient(serverUrlString: form.serverUrl) else {
      return
    }

    apiTask = Task {
      defer { self.apiTask = nil }
      let publicSystemInfo = try await apiClient.send(Paths.getPublicSystemInfo)
        self.connectionState = .foundServer
        self.form.serverName = publicSystemInfo.value.serverName
    }
  }
  
  @MainActor
  func handleSignInAction() {
    guard canSignIn else {
      return
    }
    
    guard let apiClient = JellyfinConnectionService.createClient(serverUrlString: form.serverUrl) else {
      return
    }
    
    let username = form.username
    let password = form.password
    apiTask = Task {
      defer { self.apiTask = nil }
      let authResult = try await apiClient.signIn(username: username, password: password)
      if let _ = authResult.accessToken, let userID = authResult.user?.id {
        self.connectionState = .connected
        self.onTransition?(.signInFinished(userID: userID, client: apiClient))
      }
    }
  }
  
  @MainActor
  func handleSignOutAction() {
    onTransition?(.signOut)
  }
  
  @MainActor
  func handleGoToLibraryAction() {
    guard canGoToLibrary else {
      return
    }
    
    onTransition?(.showLibrary)
  }
}
