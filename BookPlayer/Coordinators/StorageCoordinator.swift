//
//  StorageCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 29/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import Foundation
import BookPlayerKit

class StorageCoordinator: Coordinator {
  let libraryService: LibraryServiceProtocol

  init(
    libraryService: LibraryServiceProtocol,
    presentingViewController: UIViewController?
  ) {
    self.libraryService = libraryService

    super.init(
      navigationController: AppNavigationController.instantiate(from: .Main),
      flowType: .modal
    )
    self.presentingViewController = presentingViewController
  }

  override func start() {
    let vc = StorageViewController.instantiate(from: .Settings)

    let viewModel = StorageViewModel(libraryService: self.libraryService,
                                     folderURL: DataManager.getProcessedFolderURL())
    viewModel.coordinator = self
    vc.viewModel = viewModel
    vc.navigationItem.largeTitleDisplayMode = .never

    self.navigationController.viewControllers = [vc]
    self.navigationController.presentationController?.delegate = self
    self.presentingViewController?.present(self.navigationController, animated: true, completion: nil)
  }

  override func interactiveDidFinish(vc: UIViewController) {
    guard let vc = vc as? StorageViewController else { return }

    vc.viewModel.coordinator.detach()
  }
}
