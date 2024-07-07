//
//  SecondOnboardingCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 1/6/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Foundation
import SwiftUI

/// Handle second onboarding flows
class SecondOnboardingCoordinator: Coordinator {
  let anonymousId: String
  let accountService: AccountServiceProtocol
  let eventsService: EventsServiceProtocol
  let flow: BPCoordinatorPresentationFlow
  unowned var presentedController: UIViewController?

  init(
    flow: BPCoordinatorPresentationFlow,
    anonymousId: String,
    accountService: AccountServiceProtocol,
    eventsService: EventsServiceProtocol
  ) {
    self.flow = flow
    self.anonymousId = anonymousId
    self.accountService = accountService
    self.eventsService = eventsService
  }

  func start() {
    Task {
      let response: SecondOnboardingResponse = try await accountService.getSecondOnboarding()

      await showOnboarding(data: response)
    }
  }

  @MainActor
  func showOnboarding(data: SecondOnboardingResponse) {
    switch data.type {
    case .support:
      let coordinator = SupportFlowCoordinator(
        flow: flow,
        anonymousId: anonymousId,
        onboardingId: data.onboardingId,
        stories: data.support,
        accountService: accountService, 
        eventsService: eventsService
      )
      coordinator.start()
    }
  }

  func showAlert(_ content: BPAlertContent) {
    presentedController?.showAlert(content)
  }

  func showLoader() {
    if let vc = presentedController {
      LoadingUtils.loadAndBlock(in: vc)
    }
  }

  func stopLoader() {
    if let vc = presentedController {
      LoadingUtils.stopLoading(in: vc)
    }
  }

  func showCongrats() {
    presentedController?.view.startConfetti()
    presentedController?.showAlert("thanks_amazing_title".localized, message: nil) { [weak self] in
      self?.flow.finishPresentation(animated: true)
    }
  }
}
