//
//  ImportCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 10/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import UIKit

class ImportCoordinator: NSObject, Coordinator, UIAdaptivePresentationControllerDelegate {
  let importManager: ImportManager
  weak var importViewController: ImportViewController?
  let flow: BPCoordinatorPresentationFlow

  init(
    flow: BPCoordinatorPresentationFlow,
    importManager: ImportManager
  ) {
    self.flow = flow
    self.importManager = importManager
  }

  func start() {
    let vc = ImportViewController.instantiate(from: .Main)
    vc.presentationController?.delegate = self
    self.importViewController = vc
    let viewModel = ImportViewModel(importManager: self.importManager)
    viewModel.coordinator = self
    vc.viewModel = viewModel
    flow.startPresentation(vc, animated: true)
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    try? self.importViewController?.viewModel.discardImportOperation()
  }
}
