//
//  MainCoordinatorTests.swift
//  BookPlayerTests
//
//  Created by Gianni Carlo on 10/30/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import Foundation

@testable import BookPlayer
@testable import BookPlayerKit
import XCTest

class MainCoordinatorTests: XCTestCase {
  var mainCoordinator: MainCoordinator!

  override func setUp() {
    let rootVC = RootViewController.instantiate(from: .Main)
    rootVC.loadView()
    let coreServices = AppDelegate.shared!.createCoreServicesIfNeeded(from: CoreDataStack(testPath: "/dev/null"))
    self.mainCoordinator = MainCoordinator(
      rootController: rootVC,
      coreServices: coreServices,
      navigationController: UINavigationController()
    )
  }

  func testInitialState() {
    self.mainCoordinator.start()
    XCTAssert(self.mainCoordinator.childCoordinators.count == 1)
    XCTAssertNotNil(self.mainCoordinator.getLibraryCoordinator())
  }

  func testShowPlayer() {
    self.mainCoordinator.start()
    self.mainCoordinator.showPlayer()

    XCTAssert(self.mainCoordinator.childCoordinators.count == 2)
    XCTAssert(self.mainCoordinator.hasPlayerShown())
  }
}

class MockCoordinator: Coordinator {
  override func start() {
    let vc = UIViewController()

    switch self.flowType {
    case .modal:
      self.navigationController.present(vc, animated: false, completion: nil)
    case .push:
      self.navigationController.pushViewController(vc, animated: false)
    }
  }
}
