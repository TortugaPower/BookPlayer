//
//  SimpleAccount.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 31/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import Foundation

public struct SimpleAccount {
  public var id: String
  public var email: String
  public var hasSubscription: Bool
  public var donationMade: Bool
}

extension SimpleAccount {
  public init(account: Account) {
    self.id = account.id
    self.email = account.email
    self.hasSubscription = account.hasSubscription
    self.donationMade = account.donationMade
  }
}
