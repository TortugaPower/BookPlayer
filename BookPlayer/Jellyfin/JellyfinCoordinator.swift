//
//  JellyfinCoordinator.swift
//  BookPlayer
//
//  Created by Lysann Schlegel on 2024-10-26.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import Foundation
import JellyfinAPI
import UIKit

class JellyfinCoordinator: Coordinator {
  let flow: BPCoordinatorPresentationFlow

  var libraryName: String?
  var apiClient: JellyfinClient?

  init(flow: BPCoordinatorPresentationFlow) {
    self.flow = flow
  }

  private var isLogginIn: Bool { get { self.apiClient?.accessToken != nil } }

  func start() {
    let vc = if isLogginIn {
      createJellyfinLibraryScreen(withLibraryName: libraryName ?? "", client: self.apiClient!)
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
      case .loginFinished(let libraryName, let client):
        self.libraryName = libraryName
        self.apiClient = client
        let libraryVC = self.createJellyfinLibraryScreen(withLibraryName: libraryName, client: client)
        self.flow.pushViewController(libraryVC, animated: true)
      }
    }

    return vc
  }

  private func createJellyfinLibraryScreen(withLibraryName libraryName: String, client: JellyfinClient) -> UIViewController {
    let viewModel = JellyfinLibraryViewModel(libraryName: libraryName, apiClient: client)
    viewModel.coordinator = self
    let vc = JellyfinLibraryViewController(viewModel: viewModel, apiClient: client)
    return vc
  }
}
