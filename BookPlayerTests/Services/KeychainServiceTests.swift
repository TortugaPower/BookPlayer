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
    try? self.sut.removeAccessToken()
  }

  func testSettingAndGettingKey() throws {
    let emptyToken = try! self.sut.getAccessToken()
    XCTAssert(emptyToken == nil)
    try! self.sut.setAccessToken("test token")
    let token = try! self.sut.getAccessToken()
    XCTAssert(token == "test token")
    try! self.sut.setAccessToken("updated token")
    let updatedToken = try! self.sut.getAccessToken()
    XCTAssert(updatedToken == "updated token")
  }
}
