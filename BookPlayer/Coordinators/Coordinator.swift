//
//  Coordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import UIKit

public enum FlowType {
  case push, modal
}

class Coordinator: NSObject {
  var childCoordinators = [Coordinator]()
  var navigationController: UINavigationController
  weak var parentCoordinator: Coordinator?
  weak var presentingViewController: UIViewController?
  let flowType: FlowType

  init(navigationController: UINavigationController,
       flowType: FlowType) {
    self.navigationController = navigationController
    self.flowType = flowType
  }

  public func start() {
    fatalError("Coordinator is an abstract class, override this function in the subclass")
  }

  public func didFinish() {
    switch self.flowType {
    case .modal:
      self.presentingViewController?.dismiss(animated: true, completion: { [weak self] in
        self?.detach()
      })
    case .push:
      self.navigationController.popViewController(animated: true)
      self.detach()
    }
  }

  // Clean up for interactive pop gestures, this should be handled in the subclass
  public func interactiveDidFinish(vc: UIViewController) { }

  private func childDidFinish(_ child: Coordinator?) {
    guard let index = self.childCoordinators.firstIndex(where: { $0 === child }) else { return }
    self.childCoordinators.remove(at: index)
  }

  public func detach() {
    self.parentCoordinator?.childDidFinish(self)
  }

  public func showAlert(_ title: String? = nil, message: String? = nil, completion: (() -> Void)? = nil) {
    self.navigationController.showAlert(title, message: message, completion: completion)
  }

  public func getMainCoordinator() -> MainCoordinator? { return nil }
}

extension Coordinator: UINavigationControllerDelegate {
  // Handle vcs being popped interactively
  func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
    // Read the view controller we’re moving from.
    guard let fromViewController = navigationController.transitionCoordinator?.viewController(forKey: .from) else {
      return
    }

    // Check whether our view controller array already contains that view controller. If it does it means we’re pushing a different view controller on top rather than popping it, so exit.
    if navigationController.viewControllers.contains(fromViewController) {
      return
    }

    // In the coordinator subclass, this should be handled to call detach() on the proper coordinator
    self.interactiveDidFinish(vc: fromViewController)
  }
}

extension Coordinator: UIAdaptivePresentationControllerDelegate {
  // Handle modals being dismissed interactively
  public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    self.detach()
  }
}
