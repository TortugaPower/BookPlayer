//
//  AccountService.swift
//  BookPlayer
//
//  Created by gianni.carlo on 10/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import CoreData
import Foundation

public protocol AccountServiceProtocol {
  func getAccount() -> Account?
  func hasAccount() -> Bool

  func createAccount(donationMade: Bool)

  func updateAccount(
    id: String?,
    email: String?,
    donationMade: Bool?,
    hasSubscription: Bool?,
    accessToken: String?
  )

  func logout()
  func deleteAccount()
}

public final class AccountService: AccountServiceProtocol {
  let dataManager: DataManager

  public init(dataManager: DataManager) {
    self.dataManager = dataManager
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

  public func updateAccount(
    id: String?,
    email: String?,
    donationMade: Bool?,
    hasSubscription: Bool?,
    accessToken: String?
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
  }

  public func logout() {
    guard let account = self.getAccount() else { return }

    account.id = ""
    account.email = ""
    account.hasSubscription = false
    account.accessToken = ""

    self.dataManager.saveContext()
  }

  public func deleteAccount() {
    guard let account = self.getAccount() else { return }

    // TODO: make network call to delete from backend

    self.dataManager.delete(account)
  }
}
