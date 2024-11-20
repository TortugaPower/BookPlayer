//
//  JellyfinCoordinator.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-10-26.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation
import JellyfinAPI
import UIKit

class JellyfinCoordinator: Coordinator {
  let flow: BPCoordinatorPresentationFlow
  private let singleFileDownloadService: SingleFileDownloadService
  private let jellyfinConnectionService: JellyfinConnectionService
  private var disposeBag = Set<AnyCancellable>()
  
  private var apiClient: JellyfinClient?
  private var userID: String?
  private var libraryName: String?
  
  init(flow: BPCoordinatorPresentationFlow, singleFileDownloadService: SingleFileDownloadService, jellyfinConnectionService: JellyfinConnectionService) {
    self.flow = flow
    self.singleFileDownloadService = singleFileDownloadService
    self.jellyfinConnectionService = jellyfinConnectionService
    
    bindObservers()
  }
  
  func bindObservers() {
    singleFileDownloadService.eventsPublisher.sink { [weak self] event in
      switch event {
      case .starting(_), .error(_, _, _):
        self?.flow.finishPresentation(animated: true)
      default:
        break
      }
    }
    .store(in: &disposeBag)
  }
  
  private var isLoggedIn: Bool {
    apiClient?.accessToken != nil && userID != nil && !userID!.isEmpty
  }
  
  func start() {
    let connectionVC = createJellyfinLoginScreen()
    flow.startPresentation(connectionVC, animated: true)

    if !isLoggedIn {
      tryLoginWithSavedConnection(connectionViewModel: connectionVC.viewModel)
    }

    if isLoggedIn {
      self.showLibraryView()
    }
  }
  
  private func tryLoginWithSavedConnection(connectionViewModel: JellyfinConnectionViewModel) {
    guard let connectionData = jellyfinConnectionService.connection,
          let apiClient = jellyfinConnectionService.createClient() else {
      return
    }
    
    connectionViewModel.loadConnectionData(from: connectionData)
    
    self.apiClient = apiClient
    self.userID = connectionData.userID
    self.libraryName = connectionData.serverName
  }

  private func createJellyfinLoginScreen() -> JellyfinConnectionViewController {
    let viewModel = JellyfinConnectionViewModel()
    viewModel.coordinator = self
    viewModel.onTransition = { [viewModel] route in
      switch route {
      case .cancel:
        viewModel.dismiss()
      case .signInFinished(let userID, let client):
        self.handleSignInFinished(userID: userID, client: client, connectionViewModel: viewModel)
      case .signOut:
        self.handleSignOut()
        viewModel.loadConnectionData(from: self.jellyfinConnectionService.connection)
      case .showLibrary:
        self.showLibraryView()
      }
    }
    
    let vc = JellyfinConnectionViewController(viewModel: viewModel)
    return vc
  }
  
  private func createJellyfinLibraryScreen(withLibraryName libraryName: String, userID: String, client: JellyfinClient) -> UIViewController {
    let viewModel = JellyfinLibraryViewModel(libraryName: libraryName, userID: userID, apiClient: client, singleFileDownloadService: singleFileDownloadService)
    viewModel.coordinator = self

    viewModel.onTransition = { route in
      switch route {
      case .done:
        break
      }
      viewModel.dismiss()
    }

    let vc = JellyfinLibraryViewController(viewModel: viewModel, apiClient: client)
    return vc
  }

  private func handleSignInFinished(userID: String, client: JellyfinClient, connectionViewModel viewModel: JellyfinConnectionViewModel) {
    if let accessToken = client.accessToken {
      let connectionData = JellyfinConnectionData(url: client.configuration.url,
                                                  serverName: viewModel.form.serverName ?? "",
                                                  userID: userID,
                                                  userName: viewModel.form.username,
                                                  accessToken: accessToken)
      jellyfinConnectionService.setConnection(connectionData, saveToKeychain: viewModel.form.rememberMe)
    }
    
    self.apiClient = client
    self.userID = userID
    self.libraryName = viewModel.form.serverName ?? ""

    self.showLibraryView()
  }

  private func showLibraryView() {
    guard let libraryName, let userID, let apiClient else {
      return
    }
    let libraryVC = self.createJellyfinLibraryScreen(withLibraryName: libraryName,
                                                     userID: userID,
                                                     client: apiClient)
    self.flow.pushViewController(libraryVC, animated: true)
  }

  private func handleSignOut() {
    jellyfinConnectionService.deleteConnection()
    
    self.apiClient = nil
    self.userID = nil
    self.libraryName = nil
  }
}
