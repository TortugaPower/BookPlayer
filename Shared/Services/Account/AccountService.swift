//
//  AccountService.swift
//  BookPlayer
//
//  Created by gianni.carlo on 10/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

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

public enum SecondOnboardingError: Error {
  case notApplicable
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
  func getAnonymousId() -> String?
  func getAccount() -> Account?
  func hasAccount() -> Bool
  func hasSyncEnabled() -> Bool
  func hasPlusAccess() -> Bool

  func createAccount(donationMade: Bool)

  func updateAccount(from customerInfo: CustomerInfo)

  func updateAccount(
    id: String?,
    email: String?,
    donationMade: Bool?,
    hasSubscription: Bool?
  )

  func getHardcodedSubscriptionOptions() -> [PricingModel]
  func getSubscriptionOptions() async throws -> [PricingModel]

  func subscribe(option: PricingModel) async throws -> Bool
  func subscribe(option: PricingOption) async throws -> Bool
  func restorePurchases() async throws -> CustomerInfo

  func loginTestAccount(token: String) async throws
  func login(
    with token: String,
    userId: String
  ) async throws -> Account?
  /// Load up stored user into RevenueCat's SDK to start listening to events
  /// - Parameter delegate: Delegate that will handle any changes to the customer info
  func loginIfUserExists(delegate: PurchasesDelegate)

  func logout() throws
  func deleteAccount() async throws -> String

  func getSecondOnboarding<T: Decodable>() async throws -> T
}

public final class AccountService: AccountServiceProtocol {
  let monthlySubscriptionId = "com.tortugapower.audiobookplayer.subscription.pro"
  let yearlySubscriptionId = "com.tortugapower.audiobookplayer.subscription.pro.yearly"
  let dataManager: DataManager
  let client: NetworkClientProtocol
  let keychain: KeychainServiceProtocol
  private let provider: NetworkProvider<AccountAPI>

  public init(
    dataManager: DataManager,
    client: NetworkClientProtocol = NetworkClient(),
    keychain: KeychainServiceProtocol = KeychainService()
  ) {
    self.dataManager = dataManager
    self.client = client
    self.keychain = keychain
    self.provider = NetworkProvider(client: client)
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

  public func getAnonymousId() -> String? {
    return Purchases.shared.cachedCustomerInfo?.id
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

  public func hasSyncEnabled() -> Bool {
    return Purchases.shared.cachedCustomerInfo?.entitlements.all["pro"]?.isActive == true
  }

  public func hasPlusAccess() -> Bool {
    let entitlements = Purchases.shared.cachedCustomerInfo?.entitlements.all

    return entitlements?["plus"]?.isActive == true ||
    entitlements?["pro"]?.isActive == true ||
    getAccount()?.donationMade == true
  }

  public func createAccount(donationMade: Bool) {
    let context = self.dataManager.getContext()
    let account = Account.create(in: context)
    account.id = ""
    account.email = ""
    account.hasSubscription = false
    account.donationMade = donationMade
    self.dataManager.saveContext()
  }

  public func updateAccount(from customerInfo: CustomerInfo) {
    self.updateAccount(
      hasSubscription: !customerInfo.activeSubscriptions.isEmpty
    )
  }

  public func updateAccount(
    id: String? = nil,
    email: String? = nil,
    donationMade: Bool? = nil,
    hasSubscription: Bool? = nil
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

    self.dataManager.saveContext()

    DispatchQueue.main.async {
      NotificationCenter.default.post(name: .accountUpdate, object: self)
    }
  }

  public func getHardcodedSubscriptionOptions() -> [PricingModel] {
    return [
      PricingModel(id: yearlySubscriptionId, title: "49.99 USD \("yearly_title".localized)"),
      PricingModel(id: monthlySubscriptionId, title: "4.99 USD \("monthly_title".localized)")
    ]
  }

  public func getSubscriptionOptions() async throws -> [PricingModel] {
    let products = await Purchases.shared.products([yearlySubscriptionId, monthlySubscriptionId])

    var options = [PricingModel]()

    if let product = products.first(where: { $0.productIdentifier == yearlySubscriptionId }) {
      options.append(PricingModel(
        id: product.productIdentifier,
        title: "\(product.localizedPriceString) \("yearly_title".localized)"
      ))
    }

    if let product = products.first(where: { $0.productIdentifier == monthlySubscriptionId }) {
      options.append(PricingModel(
        id: product.productIdentifier,
        title: "\(product.localizedPriceString) \("monthly_title".localized)"
      ))
    }

    if options.isEmpty {
      throw AccountError.emptyProducts
    }

    return options
  }

  public func subscribe(option: PricingModel) async throws -> Bool {
    return try await subscribe(productId: option.id)
  }

  public func subscribe(option: PricingOption) async throws -> Bool {
    return try await subscribe(productId: option.rawValue)
  }

  private func subscribe(productId: String) async throws -> Bool {
    let products = await Purchases.shared.products([productId])

    guard let product = products.first else {
      throw AccountError.emptyProducts
    }

    let result = try await Purchases.shared.purchase(product: product)

    if !result.userCancelled {
      self.updateAccount(donationMade: true, hasSubscription: true)
    }

    return result.userCancelled
  }

  public func restorePurchases() async throws -> CustomerInfo {
    return try await Purchases.shared.restorePurchases()
  }

  public func loginTestAccount(token: String) async throws {
    let userId = "001918.a2d23624056d45618b7c2699d98c535e.2333"
    self.updateAccount(
      id: userId,
      email: "gcarlo89@hotmail.com",
      donationMade: true,
      hasSubscription: true
    )

    try self.keychain.setAccessToken(token)

    _ = try await Purchases.shared.logIn(userId)
  }

  public func login(
    with token: String,
    userId: String
  ) async throws -> Account? {
    let response: LoginResponse = try await provider.request(.login(token: token))

    try self.keychain.setAccessToken(response.token)

    let (customerInfo, _) = try await Purchases.shared.logIn(userId)

    if let existingAccount = self.getAccount() {
      // Preserve donation made flag from stored account
      let donationMade = existingAccount.donationMade || !customerInfo.nonSubscriptions.isEmpty

      self.updateAccount(
        id: userId,
        email: response.email,
        donationMade: donationMade,
        hasSubscription: !customerInfo.activeSubscriptions.isEmpty
      )
    }

    return self.getAccount()
  }

  public func loginIfUserExists(delegate: PurchasesDelegate) {
    guard let account = self.getAccount(), !account.id.isEmpty else {
      Purchases.shared.delegate = delegate
      return
    }

    Purchases.shared.logIn(account.id) { [weak self] customerInfo, _, _ in
      defer {
        Purchases.shared.delegate = delegate
      }

      guard let customerInfo = customerInfo else { return }

      self?.updateAccount(from: customerInfo)
    }
  }

  public func logout() throws {
    try self.keychain.removeAccessToken()

    self.updateAccount(
      id: "",
      email: "",
      hasSubscription: false
    )

    Purchases.shared.logOut { _, _ in }

    NotificationCenter.default.post(name: .logout, object: self)
  }

  public func deleteAccount() async throws -> String {
    let response: DeleteResponse = try await provider.request(.delete)

    try logout()

    return response.message
  }

  public func getSecondOnboarding<T: Decodable>() async throws -> T {
    guard
      let customerInfo = Purchases.shared.cachedCustomerInfo,
      customerInfo.activeSubscriptions.isEmpty,
      let countryCode = await Storefront.currentStorefront?.countryCode
    else {
      throw SecondOnboardingError.notApplicable
    }

    return try await provider.request(.secondOnboarding(
      anonymousId: customerInfo.id,
      firstSeen: customerInfo.firstSeen.timeIntervalSince1970,
      region: countryCode
    ))
  }
}
