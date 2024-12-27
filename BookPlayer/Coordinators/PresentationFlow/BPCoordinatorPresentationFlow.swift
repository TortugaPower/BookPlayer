//
//  CoordinatorFlow.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 18/9/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import UIKit

public protocol BPCoordinatorPresentationFlow {
  /// Navigation used for the flow of the coordinator
  var navigationController: UINavigationController { get }
  /// Start the flow with the specified starting screen
  /// - Parameters:
  ///   - viewController: The starting `UIViewController` in the coordinator's flow
  ///   - animated: Specifies if we want the transition animated or not
  func startPresentation(_ viewController: UIViewController, animated: Bool)
  /// Push the next `UIViewController` on top of ``navigationController``
  /// - Parameters:
  ///   - viewController: The next `UIViewController` in the coordinator's flow
  ///   - animated: Specifies if we want the transition animated or not
  func pushViewController(_ viewController: UIViewController, animated: Bool)
  /// Finish presentation of the flow
  /// - Parameter animated: Specifies if we want the dismiss transition animated or not
  func finishPresentation(animated: Bool)
}

/// Convenience default implementation for the functions that should work the same across different implementations
extension BPCoordinatorPresentationFlow {
  /// Push the next `UIViewController` on top of ``navigationController``
  /// - Parameters:
  ///   - viewController: The next `UIViewController` in the coordinator's flow
  ///   - animated: Specifies if we want the transition animated or not
  public func pushViewController(_ viewController: UIViewController, animated: Bool) {
    navigationController.pushViewController(viewController, animated: animated)
  }
}
