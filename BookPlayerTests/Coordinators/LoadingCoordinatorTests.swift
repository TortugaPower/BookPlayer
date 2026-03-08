//
//  LoadingCoordinatorTests.swift
//  BookPlayerTests
//
//  Created by Gianni Carlo on 30/10/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import Foundation

@testable import BookPlayer
@testable import BookPlayerKit
import XCTest

@MainActor
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

  @MainActor
  func testFinishedLoadingSequence() async {
    _ = await AppServices.shared.setupCoreServicesTask?.result
    self.loadingCoordinator.didFinishLoadingSequence()
    XCTAssertNotNil(self.loadingCoordinator.getMainCoordinator())
  }
}
