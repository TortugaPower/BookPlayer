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

  var apiClient: JellyfinClient?

  init(flow: BPCoordinatorPresentationFlow) {
    self.flow = flow
  }

  private var isLogginIn: Bool { get { self.apiClient?.accessToken != nil } }

  func start() {
    let vc = if isLogginIn {
      createJellyfinLibraryScreen(withClient: self.apiClient!)
    } else {
      createJellyfinLoginScreen()
    }
    flow.startPresentation(vc, animated: true)
  }

  private func createJellyfinLoginScreen() -> UIViewController {
    let viewModel = JellyfinConnectionViewModel()
    let vc = JellyfinConnectionViewController(viewModel: viewModel)

    viewModel.onTransition = { [vc] route in
      switch route {
      case .cancel:
        vc.dismiss(animated: true)
      case .loginFinished(let client):
        self.apiClient = client
        let libraryVC = self.createJellyfinLibraryScreen(withClient: client)
        self.flow.pushViewController(libraryVC, animated: true)
      }
    }

    vc.navigationItem.largeTitleDisplayMode = .never
    return vc
  }

  private func createJellyfinLibraryScreen(withClient: JellyfinClient) -> UIViewController {
    let viewModel = JellyfinLibraryViewModel()
    let vc = JellyfinLibraryViewController(viewModel: viewModel, apiClient: self.apiClient!)

    vc.navigationItem.largeTitleDisplayMode = .never
    return vc
  }
}
