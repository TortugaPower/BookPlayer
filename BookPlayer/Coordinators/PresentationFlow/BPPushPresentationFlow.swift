//
//  BPPushPresentationFlow.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 18/9/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import UIKit

/// Handle the push presentation requirements for Coordinators
public struct BPPushPresentationFlow: BPCoordinatorPresentationFlow {
  /// Navigation used for the flow of the coordinator
  public unowned let navigationController: UINavigationController
  /// First controller on the ``navigationController`` stack before starting the presentation
  unowned let initiatingController: UIViewController?

  /// Initializer
  /// - Parameter navigationController: Controller used for the flow of the coordinator
  public init(navigationController: UINavigationController) {
    self.navigationController = navigationController
    self.initiatingController = navigationController.viewControllers.last
  }

  /// Start the flow by pushing the specified screen on the navigation stack
  /// - Parameters:
  ///   - viewController: The starting `UIViewController` in the coordinator's flow
  ///   - animated: Specifies if we want the push transition animated or not
  public func startPresentation(_ viewController: UIViewController, animated: Bool) {
    navigationController.pushViewController(viewController, animated: animated)
  }

  /// Pops to the initiating UIViewController or to the root UIViewController if there wasn't an initiating controller
  /// - Parameter animated: Specifies if we want the dismiss transition animated or not
  public func finishPresentation(animated: Bool) {
    if let initiatingController = initiatingController {
      navigationController.popToViewController(initiatingController, animated: animated)
    } else {
      navigationController.popToRootViewController(animated: animated)
    }
  }
}

/// Improve discoverability for `BPPushPresentationFlow`
extension BPCoordinatorPresentationFlow {
  /// Push presentation for the coordinator flow
  /// - Parameter navigationController: Controller used for the flow of the coordinator
  public static func pushFlow(
    navigationController: UINavigationController
  ) -> Self where Self == BPPushPresentationFlow {
    return .init(navigationController: navigationController)
  }
}
