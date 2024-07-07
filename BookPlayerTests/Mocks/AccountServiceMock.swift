//
//  AccountServiceMock.swift
//  BookPlayerTests
//
//  Created by gianni.carlo on 23/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Foundation
import RevenueCat

class AccountServiceMock: AccountServiceProtocol {
  func getAnonymousId() -> String? {
    return nil
  }

  func hasSyncEnabled() -> Bool {
    return false
  }

  func hasPlusAccess() -> Bool {
    return false
  }

  func getSecondOnboarding<T: Decodable>() async throws -> T {
    throw BookPlayerError.cancelledTask
  }

  var account: Account?

  init(account: Account?) {
    self.account = account
  }

  func getAccountId() -> String? {
    return self.account?.id
  }

  func getAccount() -> Account? {
    return self.account
  }

  func hasAccount() -> Bool {
    return self.account != nil
  }

  func createAccount(donationMade: Bool) {
    self.account?.donationMade = donationMade
  }

  func setDelegate(_ delegate: PurchasesDelegate) { }

  func updateAccount(from customerInfo: CustomerInfo) {
    self.updateAccount(
      hasSubscription: !customerInfo.activeSubscriptions.isEmpty
    )
  }

  func updateAccount(
    id: String? = nil,
    email: String? = nil,
    donationMade: Bool? = nil,
    hasSubscription: Bool? = nil
  ) {
    if let id = id {
      account?.id = id
    }

    if let email = email {
      account?.email = email
    }

    if let donationMade = donationMade {
      account?.donationMade = donationMade
    }

    if let hasSubscription = hasSubscription {
      account?.hasSubscription = hasSubscription
    }
  }

  func getHardcodedSubscriptionOptions() -> [BookPlayerKit.PricingModel] {
    return []
  }

  func getSubscriptionOptions() async throws -> [BookPlayerKit.PricingModel] {
    return []
  }

  func subscribe(option: BookPlayerKit.PricingModel) async throws -> Bool {
    self.account?.hasSubscription = true
    return true
  }

  func subscribe(option: BookPlayerKit.PricingOption) async throws -> Bool {
    self.account?.hasSubscription = true
    return true
  }

  func restorePurchases() async throws -> CustomerInfo {
    self.account?.hasSubscription = true
    return try await Purchases.shared.customerInfo()
  }

  func loginIfUserExists(delegate: PurchasesDelegate) {}

  func login(with token: String, userId: String) async throws -> Account? {
    self.account?.id = userId
    return self.account
  }

  func loginTestAccount(token: String) async throws {}

  func logout() throws {}

  func deleteAccount() async throws -> String { return "Success" }
}
