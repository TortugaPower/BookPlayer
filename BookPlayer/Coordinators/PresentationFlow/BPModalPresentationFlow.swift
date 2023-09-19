//
//  BPModalPresentationFlow.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 18/9/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import UIKit

/// Handle the modal presentation requirements for Coordinators
public class BPModalPresentationFlow: BPCoordinatorPresentationFlow {
  /// Accessor to the flow navigation controller presented on ``startPresentation(_:animated:)``
  public var navigationController: UINavigationController {
    return _navigationController
  }
  /// Holds the unowned reference to the navigation controller internally created and presented for the flow
  private unowned var _navigationController: UINavigationController!

  /// Controller that will present the ``navigationController`` on ``startPresentation(_:animated:)``
  unowned let presentingController: UIViewController
  /// Modal presentation style
  let modalPresentationStyle: UIModalPresentationStyle

  /// Initializer
  /// - Parameter presentingController: Controller used to present ``navigationController``
  /// - Note: ``modalPresentationStyle`` has a default value of `fullScreen`, if you'd like to specify the value, please use
  /// the initializer ``init(presentingController:modalPresentationStyle:)``
  public init(presentingController: UIViewController) {
    self.presentingController = presentingController
    self.modalPresentationStyle = .fullScreen
  }

  /// Initializer
  /// - Parameters:
  ///   - presentingController: Controller used to present ``navigationController``
  ///   - modalPresentationStyle: Modal presentation style
  public init(presentingController: UIViewController, modalPresentationStyle: UIModalPresentationStyle) {
    self.presentingController = presentingController
    self.modalPresentationStyle = modalPresentationStyle
  }

  /// Start the flow by presenting a new instance of `UINavigationController` with the specified screen as the root
  /// controller
  /// - Parameters:
  ///   - viewController: The starting `UIViewController` in the coordinator's flow
  ///   - animated: Specifies if we want the present transition animated or not
  public func startPresentation(_ viewController: UIViewController, animated: Bool) {
    let nav = UINavigationController(rootViewController: viewController)
    nav.modalPresentationStyle = modalPresentationStyle
    _navigationController = nav
    presentingController.present(nav, animated: animated, completion: nil)
  }

  /// Dismiss the ``navigationController``
  /// - Parameter animated: Specifies if we want the dismiss transition animated or not
  public func finishPresentation(animated: Bool) {
    presentingController.dismiss(animated: animated)
  }
}

/// Improve discoverability for `ACModalPresentationFlow`
extension BPCoordinatorPresentationFlow {
  /// Modal presentation for the coordinator flow
  /// - Parameter presentingController: Controller that presents the navigation controller with the flow
  public static func modalFlow(
    presentingController: UIViewController
  ) -> Self where Self == BPModalPresentationFlow {
    return .init(presentingController: presentingController)
  }

  /// Modal presentation for the coordinator flow
  /// - Parameters:
  ///   - presentingController: Controller that presents the navigation controller with the flow
  ///   - modalPresentationStyle: Modal presentation style
  public static func modalFlow(
    presentingController: UIViewController,
    modalPresentationStyle: UIModalPresentationStyle
  ) -> Self where Self == BPModalPresentationFlow {
    return .init(presentingController: presentingController, modalPresentationStyle: modalPresentationStyle)
  }
}
