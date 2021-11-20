//
//  MiniPlayerViewModelTests.swift
//  BookPlayerTests
//
//  Created by Gianni Carlo on 11/20/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import Foundation

@testable import BookPlayer
@testable import BookPlayerKit
import Combine
import XCTest

class MiniPlayerViewModelTests: XCTestCase {
  var sut: MiniPlayerViewModel!
  var playerMock: PlayerManagerMock!

  override func setUp() {
    self.playerMock = PlayerManagerMock()
    self.sut = MiniPlayerViewModel(playerManager: self.playerMock)
  }

  func testShowPlayer() {
    let rootVC = RootViewController.instantiate(from: .Main)
    rootVC.loadView()
    let mainCoordinator = MainCoordinator(rootController: rootVC,
                                          dataManager: DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null")),
                                          navigationController: UINavigationController())
    self.sut.coordinator = mainCoordinator

    XCTAssert(mainCoordinator.childCoordinators.isEmpty)

    self.sut.showPlayer()

    XCTAssert(mainCoordinator.childCoordinators.count == 1)
  }

  func testPlayPause() {
    self.sut.handlePlayPauseAction()

    XCTAssert(self.playerMock.didTriggerPlayPause == true)
  }
}
