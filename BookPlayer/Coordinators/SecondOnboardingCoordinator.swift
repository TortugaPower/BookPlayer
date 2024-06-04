//
//  SecondOnboardingCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 1/6/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Foundation

enum SecondOnboardingType {
  case support
}

/// Handle second onboarding flows
class SecondOnboardingCoordinator: Coordinator {
  let accountService: AccountServiceProtocol
  let flow: BPCoordinatorPresentationFlow

  init(
    flow: BPCoordinatorPresentationFlow,
    accountService: AccountServiceProtocol
  ) {
    self.flow = flow
    self.accountService = accountService
  }

  func start() {
    Task {
      let onboarding = try await self.accountService.getSecondOnboarding()
      /// TODO: inject response
      await showOnboarding(type: .support)
    }
  }

  @MainActor
  func showOnboarding(type: SecondOnboardingType) {
    switch type {
    case .support:
      // Show modal onboarding
      break
    }
  }
}
