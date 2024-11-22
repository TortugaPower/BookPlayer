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
import SwiftUI
import UIKit

class JellyfinCoordinator: Coordinator, AlertPresenter {
  let flow: BPCoordinatorPresentationFlow
  private let singleFileDownloadService: SingleFileDownloadService
  private let jellyfinConnectionService: JellyfinConnectionService
  private var disposeBag = Set<AnyCancellable>()
  
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
  
  func start() {
    let connectionVC = createJellyfinLoginScreen()
    flow.startPresentation(connectionVC, animated: true)
    
    tryShowLibraryView()
  }

  private func createJellyfinLoginScreen() -> UIViewController {
    let viewModel = JellyfinConnectionViewModel(jellyfinConnectionService: jellyfinConnectionService)
    
    viewModel.coordinator = self
    viewModel.onTransition = { [viewModel] route in
      switch route {
      case .cancel:
        viewModel.dismiss()
      case .signInFinished(let url, let userID, let accessToken):
        self.handleSignInFinished(url: url, userID: userID, accessToken: accessToken, connectionViewModel: viewModel)
      case .signOut:
        self.jellyfinConnectionService.deleteConnection()
      case .showLibrary:
        self.tryShowLibraryView()
      case .showAlert(let content):
        self.showAlert(content)
      }
    }
    
    let vc = UIHostingController(rootView: JellyfinConnectionView(viewModel: viewModel))
    return vc
  }
  
  private func createJellyfinLibraryScreen(withLibraryName libraryName: String, userID: String, client: JellyfinClient) -> UIViewController {
    let viewModel = JellyfinLibraryViewModel(data: .topLevel(libraryName: libraryName, userID: userID),
                                                   apiClient: client,
                                                   singleFileDownloadService: singleFileDownloadService)
    
    viewModel.onTransition = { route in
      switch route {
      case .done:
        self.flow.navigationController.dismiss(animated: true)
      case .showAlert(let content):
        self.showAlert(content)
      }
    }

    let vc = UIHostingController(rootView: JellyfinLibraryView(viewModel: viewModel))
    return vc
  }

  private func handleSignInFinished(url: URL, userID: String, accessToken: String, connectionViewModel viewModel: JellyfinConnectionViewModel) {
    let connectionData = JellyfinConnectionData(url: url,
                                                serverName: viewModel.form.serverName ?? "",
                                                userID: userID,
                                                userName: viewModel.form.username,
                                                accessToken: accessToken)
    jellyfinConnectionService.setConnection(connectionData, saveToKeychain: viewModel.form.rememberMe)
    
    self.tryShowLibraryView()
  }

  private func tryShowLibraryView() {
    guard let connectionData = jellyfinConnectionService.connection,
          let apiClient = jellyfinConnectionService.createClient() else {
      return
    }
    
    let libraryVC = self.createJellyfinLibraryScreen(withLibraryName: connectionData.serverName,
                                                     userID: connectionData.userID,
                                                     client: apiClient)
    self.flow.pushViewController(libraryVC, animated: true)
  }
}
