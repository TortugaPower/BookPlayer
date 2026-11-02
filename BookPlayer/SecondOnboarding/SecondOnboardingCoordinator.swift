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
@MainActor
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
    guard
      let stories = await Self.parseStoryData(
        data.support,
        loadProductPrices: Self.loadStoreProductPrices
      )
    else { return }

    switch data.type {
    case .support:
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

  /// The App Store prices of the given products. A product that didn't load is missing from the result:
  /// RevenueCat's `products(_:)` turns every failure (StoreKit error or timeout, unknown id) into an empty list.
  typealias ProductPricesLoader = ([String]) async -> [PricingModel]

  nonisolated static func loadStoreProductPrices(_ productIds: [String]) async -> [PricingModel] {
    return await Purchases.shared.products(productIds).map {
      PricingModel(
        id: $0.productIdentifier,
        title: $0.localizedPriceString,
        price: $0.priceDecimalNumber.doubleValue
      )
    }
  }

  /// Builds the stories, pricing each action's products. Returns nil when any of those prices didn't load:
  /// the paywall can't be shown without them, so the onboarding is skipped. Nothing was started, so the
  /// server offers it again on a later launch.
  static func parseStoryData(
    _ data: [StoryResponseModel],
    loadProductPrices: ProductPricesLoader
  ) async -> [StoryViewModel]? {
    var stories: [StoryViewModel] = []
    for model in data {
      var parsedAction: StoryActionType?

      if let action = model.action {
        let prices = await loadProductPrices(action.options + [action.defaultOption])
        let pricesById = Dictionary(prices.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        guard
          let defaultOption = pricesById[action.defaultOption],
          action.options.allSatisfy({ pricesById[$0] != nil })
        else {
          return nil
        }

        parsedAction = StoryActionType(
          options: action.options.compactMap { pricesById[$0] }.sorted { $0.price < $1.price },
          defaultOption: defaultOption,
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
