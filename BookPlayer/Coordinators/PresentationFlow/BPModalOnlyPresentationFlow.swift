//
//  BPModalOnlyPresentationFlow.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 22/9/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import UIKit

/// Handle a modal presentation without a root navigation
public class BPModalOnlyPresentationFlow: BPCoordinatorPresentationFlow {
  /// Not available in this flow
  public var navigationController: UINavigationController {
    fatalError("Navigation not available on this type of coordinator flow")
  }

  /// Controller that will present the ``presentedController`` on ``startPresentation(_:animated:)``
  unowned let presentingController: UIViewController
  /// Modal presentation style
  let modalPresentationStyle: UIModalPresentationStyle

  /// Initializer
  /// - Parameter presentingController: Controller used to present ``presentedController``
  /// - Note: ``modalPresentationStyle`` has a default value of `automatic`, if you'd like to specify the value, please use
  /// the initializer ``init(presentingController:modalPresentationStyle:)``
  public init(presentingController: UIViewController) {
    self.presentingController = presentingController
    self.modalPresentationStyle = .automatic
  }

  /// Initializer
  /// - Parameters:
  ///   - presentingController: Controller used to present ``presentedController``
  ///   - modalPresentationStyle: Modal presentation style
  public init(presentingController: UIViewController, modalPresentationStyle: UIModalPresentationStyle) {
    self.presentingController = presentingController
    self.modalPresentationStyle = modalPresentationStyle
  }

  /// Start the flow by presenting a `UIViewController`
  /// - Parameters:
  ///   - viewController: The starting `UIViewController` in the coordinator's flow
  ///   - animated: Specifies if we want the present transition animated or not
  public func startPresentation(_ viewController: UIViewController, animated: Bool) {
    viewController.modalPresentationStyle = modalPresentationStyle
    presentingController.present(viewController, animated: animated, completion: nil)
  }

  /// Dismiss the ``presentedController``
  /// - Parameter animated: Specifies if we want the dismiss transition animated or not
  public func finishPresentation(animated: Bool) {
    presentingController.dismiss(animated: animated)
  }
}

/// Improve discoverability for `BPModalOnlyPresentationFlow`
extension BPCoordinatorPresentationFlow {
  /// Modal presentation for the coordinator flow
  /// - Parameter presentingController: Controller that presents the single controller
  public static func modalOnlyFlow(
    presentingController: UIViewController
  ) -> Self where Self == BPModalOnlyPresentationFlow {
    return .init(presentingController: presentingController)
  }

  /// Modal presentation for the coordinator flow
  /// - Parameters:
  ///   - presentingController: Controller that presents the controller with the flow
  ///   - modalPresentationStyle: Modal presentation style
  public static func modalOnlyFlow(
    presentingController: UIViewController,
    modalPresentationStyle: UIModalPresentationStyle
  ) -> Self where Self == BPModalOnlyPresentationFlow {
    return .init(presentingController: presentingController, modalPresentationStyle: modalPresentationStyle)
  }
}
