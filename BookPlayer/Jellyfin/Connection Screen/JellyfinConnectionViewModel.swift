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

class JellyfinConnectionViewModel: ViewModelProtocol, ObservableObject, BPLogger {
  enum Routes {
    case cancel
    case signInFinished(
      url: URL,
      userID: String,
      userName: String,
      accessToken: String,
      serverName: String,
      saveToKeychain: Bool
    )
    case signOut
    case showLibrary
    case showAlert(content: BPAlertContent)
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
          // self.form.password is not saved (we have an access token instead). Leave the field blank.
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
      Self.logger.error("handleConnectAction called while canConnect is false")
      return
    }
    
    guard let apiClient = JellyfinConnectionService.createClient(serverUrlString: form.serverUrl) else {
      self.showErrorAlert(message: JellyfinError.noClient.localizedDescription)
      return
    }

    apiTask = Task {
      defer { self.apiTask = nil }
      do {
        let publicSystemInfo = try await apiClient.send(Paths.getPublicSystemInfo)
        await MainActor.run {
          self.connectionState = .foundServer
          self.form.serverName = publicSystemInfo.value.serverName
        }
      } catch {
        self.showErrorAlert(message: error.localizedDescription)
      }
    }
  }
  
  @MainActor
  func handleSignInAction() {
    guard canSignIn else {
      Self.logger.error("handleSignInAction called while canSignIn is false")
      return
    }
    
    guard let apiClient = JellyfinConnectionService.createClient(serverUrlString: form.serverUrl) else {
      self.showErrorAlert(message: JellyfinError.noClient.localizedDescription)
      return
    }
    
    let username = form.username
    let password = form.password
    apiTask = Task {
      defer { self.apiTask = nil }
      do {
        let authResult = try await apiClient.signIn(username: username, password: password)
        if let accessToken = authResult.accessToken, let userID = authResult.user?.id {
          self.connectionState = .connected
          self.onTransition?(.signInFinished(
            url: apiClient.configuration.url,
            userID: userID,
            userName: form.username,
            accessToken: accessToken,
            serverName: form.serverName ?? "",
            saveToKeychain: form.rememberMe
          ))
        } else {
          self.showErrorAlert(message: JellyfinError.unexpectedResponse(code: nil).localizedDescription)
        }
      } catch APIError.unacceptableStatusCode(let statusCode) {
        switch statusCode {
        case 400...499:
          self.showErrorAlert(message: JellyfinError.clientError(code: statusCode).localizedDescription)
        default:
          self.showErrorAlert(message: JellyfinError.unexpectedResponse(code: statusCode).localizedDescription)
        }
      } catch {
        self.showErrorAlert(message: error.localizedDescription)
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
      Self.logger.error("handleGoToLibraryAction called while canGoToLibrary is false")
      return
    }
    
    onTransition?(.showLibrary)
  }
  
  @MainActor
  private func showErrorAlert(message: String) {
    self.onTransition?(.showAlert(content: BPAlertContent.errorAlert(message: message)))
  }
}
