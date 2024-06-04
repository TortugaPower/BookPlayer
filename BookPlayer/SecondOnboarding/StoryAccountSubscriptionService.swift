//
//  StoryAccountSubscriptionService.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 1/7/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Foundation

protocol StoryAccountSubscriptionProtocol {
  func hasAccount() -> Bool
  func subscribe(option: PricingOption) async throws -> Bool
  func getSecondOnboarding<T: Decodable>() async throws -> T
}

struct StoryAccountSubscriptionService: StoryAccountSubscriptionProtocol {
  var accountService: AccountServiceProtocol

  func hasAccount() -> Bool {
    return accountService.hasAccount()
  }

  func subscribe(option: PricingOption) async throws -> Bool {
    return try await accountService.subscribe(option: option)
  }

  func getSecondOnboarding<T: Decodable>() async throws -> T {
    return try await accountService.getSecondOnboarding()
  }
}
