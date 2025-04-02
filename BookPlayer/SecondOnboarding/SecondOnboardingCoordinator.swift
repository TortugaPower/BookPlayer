//
//  SecondOnboardingCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 1/6/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation
import RevenueCat
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
  func showOnboarding(data: SecondOnboardingResponse) async {
    switch data.type {
    case .support:
      let stories = await parseStoryData(data.support)

      let coordinator = SupportFlowCoordinator(
        flow: flow,
        anonymousId: anonymousId,
        onboardingId: data.onboardingId,
        stories: stories,
        onlyTipJar: false,
        accountService: accountService,
        eventsService: eventsService
      )
      coordinator.start()
    case .tips:
      let stories = await parseStoryData(data.support)

      let coordinator = SupportFlowCoordinator(
        flow: flow,
        anonymousId: anonymousId,
        onboardingId: data.onboardingId,
        stories: stories,
        onlyTipJar: true,
        accountService: accountService,
        eventsService: eventsService
      )
      coordinator.start()
    }
  }

  func parseStoryData(_ data: [StoryResponseModel]) async -> [StoryViewModel] {
    var stories: [StoryViewModel] = []
    for model in data {
      var parsedAction: StoryActionType?

      if let action = model.action {
        let products = await Purchases.shared.products(action.options)
        let pricingModels = products.map { PricingModel(
          id: $0.productIdentifier,
          title: $0.localizedPriceString,
          price: $0.priceDecimalNumber.doubleValue
        ) }.sorted { $0.price < $1.price }
        let defaultProduct = await Purchases.shared.products([action.defaultOption]).first!

        parsedAction = StoryActionType(
          options: pricingModels,
          defaultOption: PricingModel(
            id: defaultProduct.productIdentifier,
            title: defaultProduct.localizedPriceString,
            price: defaultProduct.priceDecimalNumber.doubleValue
          ),
          sliderOptions: action.sliderOptions,
          button: action.button,
          dismiss: action.dismiss,
          tipJar: action.tipJar,
          tipJarDisclaimer: action.tipJarDisclaimer
        )
      }

      stories.append(
        StoryViewModel(
          title: model.title,
          body: model.body,
          image: model.image,
          duration: model.duration,
          action: parsedAction
        )
      )
    }

    return stories
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
