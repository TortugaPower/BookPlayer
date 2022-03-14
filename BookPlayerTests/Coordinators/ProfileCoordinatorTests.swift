//
//  ProfileCoordinatorTests.swift
//  BookPlayerTests
//
//  Created by gianni.carlo on 12/3/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation

@testable import BookPlayer
@testable import BookPlayerKit
import XCTest

class ProfileCoordinatorTests: XCTestCase {
  var sut: ProfileCoordinator!

  override func setUp() {
    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))
    let libraryService = LibraryService(dataManager: dataManager)
    self.sut = ProfileCoordinator(
      libraryService: libraryService,
      navigationController: UINavigationController()
    )
    self.sut.start()
  }

  func testInitialState() {
    XCTAssert(self.sut.childCoordinators.isEmpty)
  }

  func testShowSettings() {
    self.sut.showSettings()
    XCTAssert(self.sut.childCoordinators.first is SettingsCoordinator)
  }
}
