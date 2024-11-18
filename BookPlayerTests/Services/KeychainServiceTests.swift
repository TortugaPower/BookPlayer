//
//  KeychainServiceTests.swift
//  BookPlayerTests
//
//  Created by gianni.carlo on 24/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation

@testable import BookPlayer
@testable import BookPlayerKit
import Combine
import XCTest

class KeychainServiceTests: XCTestCase {
  var sut: KeychainService!

  override func setUp() {
    self.sut = KeychainService()
    try? self.sut.remove(.token)
  }

  func testSettingAndGettingKey() throws {
    let emptyToken = try! self.sut.get(.token)
    XCTAssert(emptyToken == nil)
    try! self.sut.set("test token", key: .token)
    let token = try! self.sut.get(.token)
    XCTAssert(token == "test token")
    try! self.sut.set("updated token", key: .token)
    let updatedToken = try! self.sut.get(.token)
    XCTAssert(updatedToken == "updated token")
  }
}
