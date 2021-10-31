//
//  LoadingCoordinatorTests.swift
//  BookPlayerTests
//
//  Created by Gianni Carlo on 30/10/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import Foundation

@testable import BookPlayer
@testable import BookPlayerKit
import XCTest

class LoadingCoordinatorTests: XCTestCase {
  var loadingCoordinator: LoadingCoordinator!

  override func setUp() {
    self.loadingCoordinator = LoadingCoordinator(navigationController: UINavigationController(),
                                                 loadingViewController: LoadingViewController.instantiate(from: .Main))
    self.loadingCoordinator.start()
  }

  func testInitialState() {
    XCTAssert(self.loadingCoordinator.childCoordinators.isEmpty)
  }

  func testFinishedLoadingSequence() {
    self.loadingCoordinator.didFinishLoadingSequence(coreDataStack: CoreDataStack(testPath: "/dev/null"))

    XCTAssert(self.loadingCoordinator.childCoordinators.count == 1)
    XCTAssertNotNil(self.loadingCoordinator.getMainCoordinator())
  }
}
