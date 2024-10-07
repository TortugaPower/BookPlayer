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
  var presentingController: UINavigationController!

  override func setUp() {
    self.presentingController = MockNavigationController()
    self.loadingCoordinator = LoadingCoordinator(
      flow: .modalFlow(presentingController: self.presentingController)
    )
    self.loadingCoordinator.start()
  }

  func testFinishedLoadingSequence() {
    self.loadingCoordinator.didFinishLoadingSequence()
    XCTAssertNotNil(self.loadingCoordinator.getMainCoordinator())
  }
}
