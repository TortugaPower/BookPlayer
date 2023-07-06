//
//  StorageCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 29/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import Foundation
import BookPlayerKit
import SwiftUI

final class StorageCoordinator: Coordinator {
  private let libraryService: LibraryServiceProtocol

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
    let viewModel = StorageViewModel(libraryService: libraryService,
                                     folderURL: DataManager.getProcessedFolderURL())
    viewModel.coordinator = self

    let vc = UIHostingController(rootView: StorageView(viewModel: viewModel))

    navigationController.viewControllers = [vc]
    navigationController.presentationController?.delegate = self
    presentingViewController?.present(navigationController, animated: true)
  }

  override func interactiveDidFinish(vc: UIViewController) {
    detach()
  }
}
