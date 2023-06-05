//
//  ProfileCoordinatorTests.swift
//  BookPlayerTests
//
//  Created by gianni.carlo on 12/3/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation
import Combine

@testable import BookPlayer
@testable import BookPlayerKit
import XCTest

class ProfileCoordinatorTests: XCTestCase {
  var sut: ProfileCoordinator!

  @Published var placeholder: PlayableItem?

  override func setUp() {
    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))
    let libraryService = LibraryService(dataManager: dataManager)
    let playerManagerMock = PlayerManagerProtocolMock()
    playerManagerMock.currentItemPublisherReturnValue = $placeholder
    let syncServiceMock = SyncServiceProtocolMock()
    syncServiceMock.queuedJobsCount = 0
    self.sut = ProfileCoordinator(
      libraryService: libraryService,
      playerManager: playerManagerMock,
      accountService: AccountServiceMock(account: nil),
      syncService: syncServiceMock,
      navigationController: UINavigationController()
    )
    self.sut.start()
  }

  func testInitialState() {
    XCTAssert(self.sut.childCoordinators.isEmpty)
  }
}
