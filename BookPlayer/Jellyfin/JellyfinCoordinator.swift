//
//  JellyfinCoordinator.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-10-26.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import Foundation
import JellyfinAPI
import UIKit

class JellyfinCoordinator: Coordinator {
  let flow: BPCoordinatorPresentationFlow
  private let singleFileDownloadService: SingleFileDownloadService

  private var apiClient: JellyfinClient?
  private var userID: String?
  private var libraryName: String?

  init(flow: BPCoordinatorPresentationFlow, singleFileDownloadService: SingleFileDownloadService) {
    self.flow = flow
    self.singleFileDownloadService = singleFileDownloadService
  }

  private var isLoggedIn: Bool {
    apiClient?.accessToken != nil && userID != nil && !userID!.isEmpty
  }

  func start() {
    let vc = if isLoggedIn {
      createJellyfinLibraryScreen(withLibraryName: libraryName ?? "", userID: userID ?? "", client: self.apiClient!)
    } else {
      createJellyfinLoginScreen()
    }
    flow.startPresentation(vc, animated: true)
  }

  private func createJellyfinLoginScreen() -> UIViewController {
    let viewModel = JellyfinConnectionViewModel()
    viewModel.coordinator = self
    let vc = JellyfinConnectionViewController(viewModel: viewModel)

    viewModel.onTransition = { [viewModel] route in
      switch route {
      case .cancel:
        viewModel.dismiss()
      case .loginFinished(let libraryName, let userID, let client):
        self.apiClient = client
        self.userID = userID
        self.libraryName = libraryName
        let libraryVC = self.createJellyfinLibraryScreen(withLibraryName: libraryName, userID: userID, client: client)
        self.flow.pushViewController(libraryVC, animated: true)
      }
    }

    return vc
  }

  private func createJellyfinLibraryScreen(withLibraryName libraryName: String, userID: String, client: JellyfinClient) -> UIViewController {
    let viewModel = JellyfinLibraryViewModel(libraryName: libraryName, userID: userID, apiClient: client, singleFileDownloadService: singleFileDownloadService)
    viewModel.coordinator = self
    let vc = JellyfinLibraryViewController(viewModel: viewModel, apiClient: client)
    return vc
  }
}
