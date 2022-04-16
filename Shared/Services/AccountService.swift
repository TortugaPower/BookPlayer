//
//  AccountService.swift
//  BookPlayer
//
//  Created by gianni.carlo on 10/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Alamofire
import CoreData
import Foundation
import RevenueCat

public enum AccountError: Error {
  /// RevenueCat can't find the products
  case emptyProducts
  /// RevenueCat didn't find an active subscription
  case inactiveSubscription
  /// iOS apps running on MacOS can't show subscription management
  case managementUnavailable
  /// Sign in with Apple didn't return identityToken
  case missingToken
}

extension AccountError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .emptyProducts:
      return "Empty products!"
    case .managementUnavailable:
      return "Subscription Management is not available for iOS apps running on Macs, please go to the App Store app to manage your existing subscriptions."
    case .missingToken:
      return "Identity token not available. Please sign in again."
    case .inactiveSubscription:
      return "We couldn't find an active subscription for your account. If you believe this is an error, please contact us at support@bookplayer.app"
    }
  }
}

public protocol AccountServiceProtocol {
  func getAccountId() -> String?
  func getAccount() -> Account?
  func hasAccount() -> Bool

  func createAccount(donationMade: Bool)

  func setDelegate(_ delegate: PurchasesDelegate)

  func updateAccount(from customerInfo: CustomerInfo)

  func updateAccount(
    id: String?,
    email: String?,
    donationMade: Bool?,
    hasSubscription: Bool?,
    accessToken: String?
  )

  func subscribe() async throws -> Bool
  func showManageSubscriptions()
  func restorePurchases() async throws -> CustomerInfo

  func loginIfUserExists()
  func login(
    with token: String,
    userId: String
  ) async throws

  func logout()
  func deleteAccount()
}

public final class AccountService: AccountServiceProtocol {
  let subscriptionId = "com.tortugapower.audiobookplayer.subscription.pro"
  let apiURL = "https://api.tortugapower.com"
  let dataManager: DataManager

  public init(dataManager: DataManager) {
    self.dataManager = dataManager
  }

  public func setDelegate(_ delegate: PurchasesDelegate) {
    Purchases.shared.delegate = delegate
  }

  public func getAccountId() -> String? {
    if let account = self.getAccount(),
       !account.id.isEmpty {
      return account.id
    } else {
      return nil
    }
  }

  public func getAccount() -> Account? {
    let context = self.dataManager.getContext()
    let fetch: NSFetchRequest<Account> = Account.fetchRequest()
    fetch.returnsObjectsAsFaults = false

    return (try? context.fetch(fetch).first)
  }

  public func hasAccount() -> Bool {
    let context = self.dataManager.getContext()

    if let count = try? context.count(for: Account.fetchRequest()),
        count > 0 {
      return true
    }

    return false
  }

  public func createAccount(donationMade: Bool) {
    let context = self.dataManager.getContext()
    let account = Account.create(in: context)
    account.id = ""
    account.email = ""
    account.hasSubscription = false
    account.accessToken = ""
    account.donationMade = donationMade
    self.dataManager.saveContext()
  }

  public func updateAccount(from customerInfo: CustomerInfo) {
    let donationMade = !customerInfo.nonSubscriptionTransactions.isEmpty
    || !customerInfo.activeSubscriptions.isEmpty
    self.updateAccount(
      donationMade: donationMade,
      hasSubscription: !customerInfo.activeSubscriptions.isEmpty
    )
  }

  public func updateAccount(
    id: String? = nil,
    email: String? = nil,
    donationMade: Bool? = nil,
    hasSubscription: Bool? = nil,
    accessToken: String? = nil
  ) {
    guard let account = self.getAccount() else { return }

    if let id = id {
      account.id = id
    }

    if let email = email {
      account.email = email
    }

    if let donationMade = donationMade {
      account.donationMade = donationMade
    }

    if let hasSubscription = hasSubscription {
      account.hasSubscription = hasSubscription
    }

    if let accessToken = accessToken {
      account.accessToken = accessToken
    }

    self.dataManager.saveContext()

    NotificationCenter.default.post(name: .accountUpdate, object: self)
  }

  public func subscribe() async throws -> Bool {
    let products = await Purchases.shared.products([self.subscriptionId])

    guard let product = products.first else {
      throw AccountError.emptyProducts
    }

    let result = try await Purchases.shared.purchase(product: product)

    if !result.userCancelled {
      self.updateAccount(donationMade: true, hasSubscription: true)
    }

    return result.userCancelled
  }

  public func showManageSubscriptions() {
    Purchases.shared.showManageSubscriptions() { _ in }
  }

  public func restorePurchases() async throws -> CustomerInfo {
    return try await Purchases.shared.restorePurchases()
  }

  func login(
    with token: String,
    userId: String,
    completion: @escaping ((Error?) -> Void)
  ) {
    Alamofire.request(
      "https://api.tortugapower.com/v1/user/login",
      method: .post,
      parameters: ["token_id": token],
      encoding: JSONEncoding.default
    ).responseJSON { [weak self] response in
      switch response.result {
      case .success:
        guard let json = response.value as? [String: Any] else {
          completion(nil)
          return
        }

        self?.updateAccount(
          id: userId,
          email: json["email"] as? String,
          donationMade: nil,
          hasSubscription: nil,
          accessToken: json["token"] as? String
        )

        Purchases.shared.logIn(userId) { _, _, _ in }

        NotificationCenter.default.post(name: .accountUpdate, object: self)

        completion(nil)
      case .failure(let error):
        completion(error)
      }
    }
  }

  public func login(
    with token: String,
    userId: String
  ) async throws {
    return try await withUnsafeThrowingContinuation { continuation in
      login(with: token, userId: userId) { error in
        if let error = error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume()
        }
      }
    }
  }

  public func loginIfUserExists() {
    guard let account = self.getAccount(), !account.id.isEmpty else { return }

    Purchases.shared.logIn(account.id) { _, _, _ in }
  }

  public func logout() {
    guard let account = self.getAccount() else { return }

    account.id = ""
    account.email = ""
    account.hasSubscription = false
    account.accessToken = ""

    self.dataManager.saveContext()

    Purchases.shared.logOut { _, _ in }

    NotificationCenter.default.post(name: .accountUpdate, object: self)
  }

  public func deleteAccount() {
    guard let account = self.getAccount() else { return }

    // TODO: make network call to delete from backend

    self.dataManager.delete(account)
  }
}
