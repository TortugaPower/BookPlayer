//
//  Coordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import UIKit

class Coordinator {
  var childCoordinators = [Coordinator]()
  var navigationController: UINavigationController
  weak var parentCoordinator: Coordinator?
  weak var presentingViewController: UIViewController?

  init(navigationController: UINavigationController) {
    self.navigationController = navigationController
  }

  func start() {
    fatalError("Coordinator is an abstract class, override this function in the subclass")
  }

  func childDidFinish(_ child: Coordinator?) {
    guard let index = self.childCoordinators.firstIndex(where: { $0 === child }) else { return }
    self.childCoordinators.remove(at: index)
  }

  func dismiss() {
    self.navigationController.dismiss(animated: true) { [weak self] in
      self?.parentCoordinator?.childDidFinish(self)
    }
  }

  func detach() {
    self.parentCoordinator?.childDidFinish(self)
  }
}
