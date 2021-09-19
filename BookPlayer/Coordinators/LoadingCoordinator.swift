//
//  LoadingCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import UIKit

class LoadingCoordinator: Coordinator {
  override func start() {
    let loadingVC = LoadingViewController.instantiate(from: .Main)
    loadingVC.coordinator = self
    loadingVC.modalPresentationStyle = .fullScreen

    loadingVC.presentationController?.delegate = self
    self.navigationController.show(loadingVC, sender: self)
  }

  func didFinishLoadingSequence() {
    let rootVC = RootViewController.instantiate(from: .Main)
    let coordinator = MainCoordinator(
      rootController: rootVC,
      navigationController: AppNavigationController.instantiate(from: .Main)
    )
    rootVC.coordinator = coordinator
    rootVC.modalPresentationStyle = .fullScreen
    rootVC.modalTransitionStyle = .crossDissolve
    coordinator.parentCoordinator = self
    coordinator.presentingViewController = self.presentingViewController
    self.childCoordinators.append(coordinator)

    self.navigationController.present(rootVC, animated: true, completion: nil)
  }

  override func dismiss() {
    self.presentingViewController?.dismiss(animated: true, completion: { [weak self] in
      self?.parentCoordinator?.childDidFinish(self)
    })
  }
}
