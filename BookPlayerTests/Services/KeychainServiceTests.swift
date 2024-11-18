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

  private struct TestItem: Codable {
    var name: String
    var token: String
  }

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

  func testSettingAndGettingCodableKey() throws {
    let emptyToken: TestItem? = try! self.sut.get(.token)
    XCTAssert(emptyToken == nil)
    var testItem = TestItem(name: "test name", token: "test token")
    try! self.sut.set(testItem, key: .token)
    let item: TestItem = try! self.sut.get(.token)!
    XCTAssert(item.name == "test name")
    XCTAssert(item.token == "test token")
    testItem.token = "updated token"
    try! self.sut.set(testItem, key: .token)
    let updatedItem: TestItem = try! self.sut.get(.token)!
    XCTAssert(updatedItem.name == "test name")
    XCTAssert(updatedItem.token == "updated token")
  }
}
