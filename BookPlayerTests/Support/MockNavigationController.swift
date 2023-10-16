//
//  MockNavigationController.swift
//  BookPlayerTests
//
//  Created by Gianni Carlo on 25/9/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import UIKit

class MockNavigationController: UINavigationController {
  // MARK: - Properties
  @objc dynamic var horizontalStack = [String]()
  @objc dynamic var verticalStack = [String]()
  var isDismissCalled: Bool = false

  // MARK: - Methods
  override func pushViewController(_ viewController: UIViewController, animated: Bool) {
    super.pushViewController(viewController, animated: false)

    horizontalStack.append(viewController.testNameController)
  }

  override func popViewController(animated: Bool) -> UIViewController? {
    horizontalStack.removeLast()
    return super.popViewController(animated: animated)
  }

  override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
    super.present(viewControllerToPresent, animated: false, completion: completion)

    verticalStack.append(viewControllerToPresent.testNameController)
  }

  override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
    super.dismiss(animated: flag, completion: completion)
    isDismissCalled = true
  }

  func topViewController() -> UIViewController? {
    return viewControllers.last
  }
}

extension UIViewController {
  @objc dynamic var testNameController: String {
    String(describing: type(of: self))
  }
}
