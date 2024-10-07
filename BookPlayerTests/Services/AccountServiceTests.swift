//
//  AccountServiceTests.swift
//  BookPlayerTests
//
//  Created by gianni.carlo on 23/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation

@testable import BookPlayer
@testable import BookPlayerKit
import Combine
import XCTest

class AccountServiceTests: XCTestCase {
  var sut: AccountService!
  var mockKeychain: KeychainServiceProtocolMock!

  override func setUp() {
    DataTestUtils.clearFolderContents(url: DataManager.getProcessedFolderURL())
    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))
    self.mockKeychain = KeychainServiceProtocolMock()
    self.sut = AccountService(
      dataManager: dataManager,
      client: NetworkClientMock(mockedResponse: Empty()),
      keychain: self.mockKeychain
    )
  }

  private func setupBlankAccount() {
    let context = self.sut.dataManager.getContext()
    let account = Account.create(in: context)
    account.id = ""
    account.email = ""
    account.hasSubscription = false
    account.donationMade = false
    self.sut.dataManager.saveContext()
  }

  func testGetAccount() {
    XCTAssert(sut.getAccount() == nil)
    self.setupBlankAccount()
    XCTAssert(sut.getAccount() != nil)
  }

  func testUpdateAccount() {
    self.setupBlankAccount()
    self.sut.updateAccount(
      id: "1",
      email: "test@email.com",
      donationMade: true,
      hasSubscription: true
    )

    let storedAccount = sut.getAccount()
    XCTAssert(storedAccount?.id == "1")
    XCTAssert(storedAccount?.email == "test@email.com")
    XCTAssert(storedAccount?.donationMade == true)
    XCTAssert(storedAccount?.hasSubscription == true)
  }

  func testGetId() {
    self.setupBlankAccount()
    self.sut.updateAccount(id: "2")
    XCTAssert(self.sut.getAccountId() == "2")
  }

  func testHasAccount() {
    XCTAssert(self.sut.hasAccount() == false)
    self.setupBlankAccount()
    XCTAssert(self.sut.hasAccount() == true)
  }

  func testCreateAccount() {
    self.sut.createAccount(donationMade: true)
    let account = self.sut.getAccount()
    XCTAssert(account?.donationMade == true)
  }

  func testLogout() throws {
    self.setupBlankAccount()
    self.sut.updateAccount(
      id: "1",
      email: "test@email.com",
      donationMade: true,
      hasSubscription: true
    )

    try self.sut.logout()

    XCTAssert(try mockKeychain.getAccessToken() == nil)
    let account = self.sut.getAccount()
    XCTAssert(account?.donationMade == true)
    XCTAssert(account?.hasSubscription == false)
    XCTAssert(account?.id.isEmpty == true)
    XCTAssert(account?.email.isEmpty == true)
  }

  func testDeleteAccoount() async throws {
    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))
    let mockResponse = DeleteResponse(message: "success")
    let keychainMock = KeychainServiceProtocolMock()

    self.sut = AccountService(
      dataManager: dataManager,
      client: NetworkClientMock(mockedResponse: mockResponse),
      keychain: keychainMock
    )

    XCTAssert(self.sut.hasAccount() == false)
    self.setupBlankAccount()
    XCTAssert(self.sut.hasAccount() == true)
    let result = try await self.sut.deleteAccount()
    XCTAssert(result == "success")
    XCTAssert(self.sut.hasAccount() == true)
    XCTAssert(self.sut.getAccount()?.hasSubscription == false)
    XCTAssert(try mockKeychain.getAccessToken() == nil)
  }
}
