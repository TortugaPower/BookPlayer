//
//  PlayerCoordinatorTests.swift
//  BookPlayerTests
//
//  Created by Gianni Carlo on 30/10/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import Foundation

@testable import BookPlayer
@testable import BookPlayerKit
import XCTest

class PlayerCoordinatorTests: XCTestCase {
  var playerCoordinator: PlayerCoordinator!

  override func setUp() {
    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))
    let libraryService = LibraryService(dataManager: dataManager)

    self.playerCoordinator = PlayerCoordinator(
      playerManager: PlayerManagerMock(),
      libraryService: libraryService,
      syncService: SyncServiceMock(),
      presentingViewController: UINavigationController()
    )
    self.playerCoordinator.start()
  }

  func testInitialState() {
    XCTAssert(self.playerCoordinator.childCoordinators.isEmpty)
  }

  func testShowBookmarks() {
    self.playerCoordinator.showBookmarks()
    XCTAssert(self.playerCoordinator.childCoordinators.first is BookmarkCoordinator)
  }

  func testShowChapters() {
    self.playerCoordinator.showChapters()
    XCTAssert(self.playerCoordinator.childCoordinators.first is ChapterCoordinator)
  }
}
