//
//  AccountServiceTests.swift
//  BookPlayerTests
//
//  Created by gianni.carlo on 23/4/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import Foundation

@testable import BookPlayer
@testable import BookPlayerKit
import Combine
import XCTest

class AccountServiceTests: XCTestCase {
  var sut: AccountService!
  var mockKeychain: KeychainServiceProtocol!

  override func setUp() {
    DataTestUtils.clearFolderContents(url: DataManager.getProcessedFolderURL())
    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))
    self.mockKeychain = KeychainServiceMock()
    self.sut = AccountService()
    self.sut.setup(
      dataManager: dataManager,
      client: NetworkClientMock(mockedResponse: Empty()),
      keychain: self.mockKeychain
    )
    self.sut.dataManager.saveContext()
  }

  func testUpdateAccount() {
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
    self.sut.updateAccount(id: "2")
    XCTAssert(self.sut.getAccountId() == "2")
  }

  func testLogout() throws {
    self.sut.updateAccount(
      id: "1",
      email: "test@email.com",
      donationMade: true,
      hasSubscription: true
    )

    try self.sut.logout()

    XCTAssert(try mockKeychain.get(.token) == nil)
    let account = self.sut.getAccount()
    XCTAssert(account?.donationMade == true)
    XCTAssert(account?.hasSubscription == false)
    XCTAssert(account?.id.isEmpty == true)
    XCTAssert(account?.email.isEmpty == true)
  }

  func testDeleteAccoount() async throws {
    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))
    let mockResponse = DeleteResponse(message: "success")
    let keychainMock = KeychainServiceMock()

    self.sut = AccountService()
    self.sut.setup(
      dataManager: dataManager,
      client: NetworkClientMock(mockedResponse: mockResponse),
      keychain: keychainMock
    )

    XCTAssert(self.sut.hasAccount() == true)
    let result = try await self.sut.deleteAccount()
    XCTAssert(result == "success")
    XCTAssert(self.sut.hasAccount() == true)
    XCTAssert(self.sut.getAccount()?.hasSubscription == false)
    XCTAssert(try keychainMock.get(.token) == nil)
  }
}

// MARK: - Streaming access

/// Media-server streaming is granted to anyone who has EVER paid, so the rule has to answer
/// correctly for a history rather than for the current subscription.
final class StreamingAccessTests: XCTestCase {
  func testAnUnrefundedSubscriptionCounts() {
    XCTAssertTrue(AccountService.hasUnrefundedSubscription(refundDates: [nil]))
  }

  func testARefundOnlyHistoryDoesNot() {
    XCTAssertFalse(AccountService.hasUnrefundedSubscription(refundDates: [Date()]))
  }

  /// The reason this reads the whole dictionary instead of `getSubscriptionInfo(from:)`, which
  /// breaks on the first `PricingOption` match: a refunded pro alongside a legitimately lapsed
  /// lite must still grant access, whichever one the enum happens to list first.
  func testARefundAlongsideAGenuineSubscriptionStillCounts() {
    XCTAssertTrue(AccountService.hasUnrefundedSubscription(refundDates: [Date(), nil]))
    XCTAssertTrue(AccountService.hasUnrefundedSubscription(refundDates: [nil, Date()]))
  }

  func testNoPurchaseHistoryDoesNot() {
    XCTAssertFalse(AccountService.hasUnrefundedSubscription(refundDates: []))
  }

  // MARK: composing the rule

  func testEitherPaidClauseGrantsAccessWhenSignedIn() {
    XCTAssertTrue(
      AccountService.resolveStreamingAccess(isSignedIn: true, hasPlusAccess: true, hasEverSubscribed: false)
    )
    XCTAssertTrue(
      AccountService.resolveStreamingAccess(isSignedIn: true, hasPlusAccess: false, hasEverSubscribed: true)
    )
  }

  /// The case that prompted the sign-in clause: `donationMade` deliberately outlives logout,
  /// so a past tipper who signs out still satisfies `hasPlusAccess()` — and used to keep
  /// streaming with no account at all.
  func testPayingIsNotEnoughWhileSignedOut() {
    XCTAssertFalse(
      AccountService.resolveStreamingAccess(isSignedIn: false, hasPlusAccess: true, hasEverSubscribed: false),
      "a tip that survived logout must not reopen streaming"
    )
    XCTAssertFalse(
      AccountService.resolveStreamingAccess(isSignedIn: false, hasPlusAccess: false, hasEverSubscribed: true)
    )
  }

  /// Signing in is necessary, not sufficient — streaming is still something you have to buy.
  func testSigningInAloneDeniesAccess() {
    XCTAssertFalse(
      AccountService.resolveStreamingAccess(isSignedIn: true, hasPlusAccess: false, hasEverSubscribed: false)
    )
  }

  func testNothingPaidAndSignedOutDeniesAccess() {
    XCTAssertFalse(
      AccountService.resolveStreamingAccess(isSignedIn: false, hasPlusAccess: false, hasEverSubscribed: false)
    )
  }
}
