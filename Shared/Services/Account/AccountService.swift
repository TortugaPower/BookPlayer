//
//  AccountService.swift
//  BookPlayer
//
//  Created by gianni.carlo on 10/4/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
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
  /// In-app purchases are disabled in TestFlight builds
  case testFlightPurchasesDisabled
}

public enum SecondOnboardingError: Error {
  case notApplicable
}

public enum AccessLevel: String, CaseIterable, Identifiable {
  case free, plus, pro

  public var id: String { rawValue }
}

extension AccountError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .emptyProducts:
      return "Empty products!"
    case .managementUnavailable:
      return
        "Subscription Management is not available for iOS apps running on Macs, please go to the App Store app to manage your existing subscriptions."
    case .missingToken:
      return "Identity token not available. Please sign in again."
    case .inactiveSubscription:
      return
        "We couldn't find an active subscription for your account. If you believe this is an error, please contact us at support@bookplayer.app"
    case .testFlightPurchasesDisabled:
      return "In-app purchases are disabled in TestFlight builds. Please download the app from the App Store for donations or new subscriptions."
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

  @discardableResult
  func createAccount(donationMade: Bool) -> Account

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

@Observable
public final class AccountService: AccountServiceProtocol {
  let monthlySubscriptionId = "com.tortugapower.audiobookplayer.subscription.pro"
  let yearlySubscriptionId = "com.tortugapower.audiobookplayer.subscription.pro.yearly"
  var dataManager: DataManager!
  var client: NetworkClientProtocol!
  var keychain: KeychainServiceProtocol!
  public var account: SimpleAccount!
  private var provider: NetworkProvider<AccountAPI>!

  public var accessLevel: AccessLevel!

  public init() {}

  public func setup(
    dataManager: DataManager,
    client: NetworkClientProtocol = NetworkClient(),
    keychain: KeychainServiceProtocol = KeychainService()
  ) {
    self.dataManager = dataManager
    self.client = client
    self.keychain = keychain
    self.provider = NetworkProvider(client: client)
    self.accessLevel = getAccessLevel()

    let storedAccount: Account = getAccount() ?? createAccount(
      donationMade: UserDefaults.standard.bool(forKey: Constants.UserDefaults.donationMade)
    )

    self.account = SimpleAccount(account: storedAccount)
  }

  public func setDelegate(_ delegate: PurchasesDelegate) {
    Purchases.shared.delegate = delegate
  }

  public func getAccountId() -> String? {
    if let account = self.getAccount(),
      !account.id.isEmpty
    {
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
      count > 0
    {
      return true
    }

    return false
  }

  public func hasSyncEnabled() -> Bool {
    return Purchases.shared.cachedCustomerInfo?.entitlements.all["pro"]?.isActive == true
  }

  public func hasPlusAccess() -> Bool {
    guard let cachedInfo = Purchases.shared.cachedCustomerInfo else {
      return getAccount()?.donationMade == true
    }

    let entitlements = cachedInfo.entitlements.all

    if entitlements["plus"]?.isActive == true
      || entitlements["pro"]?.isActive == true
    {
      return true
    }

    if entitlements["pro"]?.isActive == false,
      let subscriptionInfo = getSubscriptionInfo(from: cachedInfo),
      subscriptionInfo.refundedAt != nil
    {
      return false
    }

    return getAccount()?.donationMade == true
  }

  private func getAccessLevel() -> AccessLevel {
    if hasSyncEnabled() {
      return .pro
    } else if hasPlusAccess() {
      return .plus
    } else {
      return .free
    }
  }

  private func getSubscriptionInfo(from customerInfo: CustomerInfo) -> SubscriptionInfo? {
    var currentSubscription: SubscriptionInfo?

    for option in PricingOption.allCases {
      if let subscription = customerInfo.subscriptionsByProductIdentifier[option.rawValue] {
        currentSubscription = subscription
        break
      }
    }

    return currentSubscription
  }

  @discardableResult
  public func createAccount(donationMade: Bool) -> Account {
    let context = self.dataManager.getContext()
    let account = Account.create(in: context)
    account.id = ""
    account.email = ""
    account.hasSubscription = false
    account.donationMade = donationMade
    self.dataManager.saveContext()

    return account
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
      self.accessLevel = self.getAccessLevel()
      self.account = .init(account: account)
      NotificationCenter.default.post(name: .accountUpdate, object: self)
    }
  }

  public func getHardcodedSubscriptionOptions() -> [PricingModel] {
    return [
      PricingModel(
        id: yearlySubscriptionId,
        title: "49.99 USD \("yearly_title".localized)",
        price: 49.99
      ),
      PricingModel(
        id: monthlySubscriptionId,
        title: "4.99 USD \("monthly_title".localized)",
        price: 4.99
      ),
    ]
  }

  public func getSubscriptionOptions() async throws -> [PricingModel] {
    let products = await Purchases.shared.products([yearlySubscriptionId, monthlySubscriptionId])

    var options = [PricingModel]()

    if let product = products.first(where: { $0.productIdentifier == yearlySubscriptionId }) {
      options.append(
        PricingModel(
          id: product.productIdentifier,
          title: "\(product.localizedPriceString) \("yearly_title".localized)",
          price: product.priceDecimalNumber.doubleValue
        )
      )
    }

    if let product = products.first(where: { $0.productIdentifier == monthlySubscriptionId }) {
      options.append(
        PricingModel(
          id: product.productIdentifier,
          title: "\(product.localizedPriceString) \("monthly_title".localized)",
          price: product.priceDecimalNumber.doubleValue
        )
      )
    }

    if options.isEmpty {
      throw AccountError.emptyProducts
    }

    return options
  }

  public func subscribe(option: PricingModel) async throws -> Bool {
    return try await subscribe(productId: option.id)
  }

  private func subscribe(productId: String) async throws -> Bool {
    guard AppEnvironment.isPurchaseEnabled else {
      throw AccountError.testFlightPurchasesDisabled
    }
    
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
    guard AppEnvironment.isPurchaseEnabled else {
      throw AccountError.testFlightPurchasesDisabled
    }
    
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

    try self.keychain.set(token, key: .token)

    _ = try await Purchases.shared.logIn(userId)
    UserDefaults.sharedDefaults.set(userId, forKey: "rcUserId")
  }

  public func login(
    with token: String,
    userId: String
  ) async throws -> Account? {
    let response: LoginResponse = try await provider.request(.login(token: token))

    try self.keychain.set(response.token, key: .token)

    let (customerInfo, _) = try await Purchases.shared.logIn(userId)
    UserDefaults.sharedDefaults.set(userId, forKey: "rcUserId")

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
    try self.keychain.remove(.token)

    self.updateAccount(
      id: "",
      email: "",
      hasSubscription: false
    )

    Purchases.shared.logOut { _, _ in }
    UserDefaults.sharedDefaults.removeObject(forKey: "rcUserId")

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
      let countryCode = await Storefront.currentStorefront?.countryCode
    else {
      throw SecondOnboardingError.notApplicable
    }

    let entitlements = customerInfo.entitlements.all

    if entitlements["plus"]?.isActive == true
      || entitlements["pro"]?.isActive == true
    {
      throw SecondOnboardingError.notApplicable
    }

    /// Verify that it wasn't refunded
    if entitlements["pro"]?.isActive == false,
      let subscriptionInfo = getSubscriptionInfo(from: customerInfo),
      subscriptionInfo.refundedAt == nil
    {
      throw SecondOnboardingError.notApplicable
    }

    return try await provider.request(
      .secondOnboarding(
        anonymousId: customerInfo.id,
        firstSeen: customerInfo.firstSeen.timeIntervalSince1970,
        region: countryCode,
        version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
      )
    )
  }
}
