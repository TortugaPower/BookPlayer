//
//  JellyfinCoordinator.swift
//  BookPlayer
//
//  Created by Lysann Schlegel on 2024-10-26.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import Foundation
import JellyfinAPI

class JellyfinCoordinator: Coordinator {
  let flow: BPCoordinatorPresentationFlow

  var apiClient: JellyfinClient?

  init(flow: BPCoordinatorPresentationFlow) {
    self.flow = flow
  }

  func start() {
    let viewModel = JellyfinConnectionViewModel()
    let vc = JellyfinConnectionViewController(viewModel: viewModel)

    viewModel.onTransition = { [vc] route in
      switch route {
      case .cancel:
        break
      case .loginFinished(let client):
        self.apiClient = client
        self.showJellyfinLibrary()
      }
      vc.dismiss(animated: true)
    }

    vc.navigationItem.largeTitleDisplayMode = .never
    flow.startPresentation(vc, animated: true)
  }

  private func showJellyfinLibrary() {
    guard let apiClient = self.apiClient else {
      return
    }
    guard apiClient.accessToken != nil else {
      return
    }

    let viewModel = JellyfinLibraryViewModel()
    let vc = JellyfinLibraryViewController(viewModel: viewModel, apiClient: apiClient)

    vc.navigationItem.largeTitleDisplayMode = .never
    flow.pushViewController(vc, animated: true)
  }
}
