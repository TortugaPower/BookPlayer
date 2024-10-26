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

  init(flow: BPCoordinatorPresentationFlow) {
    self.flow = flow
  }

  func start() {
    let viewModel = JellyfinConnectionViewModel()
    let vc = JellyfinConnectionViewController(viewModel: viewModel)

    viewModel.onTransition = { [vc] route in
      switch route {
      case .cancel:
        vc.dismiss(animated: true)
      case .listServerContent(let client):
        self.showJellyfinLibrary(withClient: client)
      }
    }

    vc.navigationItem.largeTitleDisplayMode = .never
    flow.startPresentation(vc, animated: true)
  }

  private func showJellyfinLibrary(withClient client: JellyfinClient) {
    let viewModel = JellyfinLibraryViewModel()
    let vc = JellyfinLibraryViewController(viewModel: viewModel, apiClient: client)

    vc.navigationItem.largeTitleDisplayMode = .never
    flow.pushViewController(vc, animated: true)
  }
}
