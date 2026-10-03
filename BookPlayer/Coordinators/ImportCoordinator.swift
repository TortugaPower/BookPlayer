//
//  ImportCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 10/9/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import UIKit

class ImportCoordinator: Coordinator {
  let importManager: ImportManager
  let flow: BPCoordinatorPresentationFlow

  init(
    flow: BPCoordinatorPresentationFlow,
    importManager: ImportManager
  ) {
    self.flow = flow
    self.importManager = importManager
  }

  func start() {
    let viewModel = ImportViewModel(importManager: self.importManager)
    viewModel.onTransition = { routes in
      switch routes {
      case .dismiss:
        self.flow.finishPresentation(animated: true)
      case .dismissAndImport:
        // Captured apart from `self`: the coordinator can be released with its screen
        let importManager = self.importManager
        self.flow.finishPresentation(animated: true) {
          importManager.createOperation()
        }
      }
    }
    let vc = ImportViewController.instantiate(from: .Main)
    vc.viewModel = viewModel
    flow.startPresentation(vc, animated: true)
    flow.navigationController.presentationController?.delegate = viewModel
  }
}
