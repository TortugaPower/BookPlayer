//
//  SettingsCoordinatorTests.swift
//  BookPlayerTests
//
//  Created by Gianni Carlo on 30/10/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import Foundation

@testable import BookPlayer
@testable import BookPlayerKit
import XCTest

class SettingsCoordinatorTests: XCTestCase {
  var settingsCoordinator: SettingsCoordinator!

  override func setUp() {
    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))

    self.settingsCoordinator = SettingsCoordinator(
      dataManager: dataManager,
      library: dataManager.createLibrary(),
      navigationController: UINavigationController()
    )
    self.settingsCoordinator.start()
  }

  func testInitialState() {
    XCTAssert(self.settingsCoordinator.childCoordinators.isEmpty)
  }

  func testShowStorageManagement() {
    self.settingsCoordinator.showStorageManagement()
    XCTAssert(self.settingsCoordinator.childCoordinators.first is StorageCoordinator)
  }
}
