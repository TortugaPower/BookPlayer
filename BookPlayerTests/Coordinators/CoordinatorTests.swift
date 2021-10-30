//
//  CoordinatorTests.swift
//  BookPlayerTests
//
//  Created by Gianni Carlo on 10/30/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import Foundation

@testable import BookPlayer
@testable import BookPlayerKit
import XCTest

class CoordinatorTests: XCTestCase {

}

class MockCoordinator: Coordinator {
  override func start() {
    let vc = UIViewController()
    self.navigationController.pushViewController(vc, animated: false)
  }
}
