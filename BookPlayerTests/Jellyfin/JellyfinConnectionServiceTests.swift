//
//  JellyfinConnectionServiceTests.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-11-22.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

@testable import BookPlayer
import BookPlayerKit
import XCTest

class JellyfinConnectionServiceTests: XCTestCase {
  var sut: JellyfinConnectionService!
  
  override func setUp() {
    sut = JellyfinConnectionService(keychainService: KeychainService())
  }
  
  func testCreateService() {
    XCTAssert(sut != nil)
  }
}
