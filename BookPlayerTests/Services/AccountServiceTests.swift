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
  var mockClient: NetworkClientMock!

  override func setUp() {
    DataTestUtils.clearFolderContents(url: DataManager.getProcessedFolderURL())
    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))
    self.sut = AccountService(dataManager: dataManager)
  }

  private func setupBlankAccount() {
    let context = self.sut.dataManager.getContext()
    let account = Account.create(in: context)
    account.id = ""
    account.email = ""
    account.hasSubscription = false
    account.accessToken = ""
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
      hasSubscription: true,
      accessToken: "access token"
    )

    let storedAccount = sut.getAccount()
    XCTAssert(storedAccount?.id == "1")
    XCTAssert(storedAccount?.email == "test@email.com")
    XCTAssert(storedAccount?.donationMade == true)
    XCTAssert(storedAccount?.hasSubscription == true)
    XCTAssert(storedAccount?.accessToken == "access token")
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

  func testLogout() {
    self.setupBlankAccount()
    self.sut.updateAccount(
      id: "1",
      email: "test@email.com",
      donationMade: true,
      hasSubscription: true,
      accessToken: "access token"
    )

    self.sut.logout()

    let account = self.sut.getAccount()
    XCTAssert(account?.donationMade == true)
    XCTAssert(account?.hasSubscription == false)
    XCTAssert(account?.id.isEmpty == true)
    XCTAssert(account?.email.isEmpty == true)
    XCTAssert(account?.accessToken.isEmpty == true)
  }

  func testDeleteAccoount() {
    XCTAssert(self.sut.hasAccount() == false)
    self.setupBlankAccount()
    XCTAssert(self.sut.hasAccount() == true)
    self.sut.deleteAccount()
    XCTAssert(self.sut.hasAccount() == false)
  }

  func testLogin() async {
    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))
    let mockResponse = LoginResponse(email: "success@test.com", token: "accessToken")

    self.sut = AccountService(
      dataManager: dataManager,
      client: NetworkClientMock(mockedResponse: mockResponse)
    )

    self.setupBlankAccount()

    let account = try! await self.sut.login(with: "identity token", userId: "3")

    XCTAssert(account?.id == "3")
    XCTAssert(account?.email == "success@test.com")
    XCTAssert(account?.donationMade == false)
    XCTAssert(account?.hasSubscription == false)
    XCTAssert(account?.accessToken == "accessToken")
  }
}
