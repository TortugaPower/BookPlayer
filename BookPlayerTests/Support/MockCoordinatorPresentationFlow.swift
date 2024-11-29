//
//  CoordinatorPresentationFlowMock.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-11-23.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import BookPlayer
import UIKit

class MockCoordinatorPresentationFlow: BPCoordinatorPresentationFlow {
  var navigationController: UINavigationController { return mockNavigationController }
  var mockNavigationController: MockNavigationController!
  
  var horizontalStack: [String] { return mockNavigationController?.horizontalStack ?? [] }
  var verticalStack: [String] { return mockNavigationController?.verticalStack ?? [] }
  
  func startPresentation(_ viewController: UIViewController, animated: Bool) {
    mockNavigationController = MockNavigationController(rootViewController: viewController)
  }
  
  func pushViewController(_ viewController: UIViewController, animated: Bool) {
    mockNavigationController.pushViewController(viewController, animated: animated)
  }
  
  func finishPresentation(animated: Bool) {
    mockNavigationController = nil
  }
}
