//
//  SupportFlowCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 30/6/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation
import SwiftUI

/// Handle second onboarding flows
class SupportFlowCoordinator: Coordinator, AlertPresenter {
  let accountService: AccountServiceProtocol
  let eventsService: EventsServiceProtocol
  let stories: [StoryViewModel]
  let flow: BPCoordinatorPresentationFlow
  let anonymousId: String
  let onboardingId: String
  let onlyTipJar: Bool
  unowned var presentedController: UIViewController?

  init(
    flow: BPCoordinatorPresentationFlow,
    anonymousId: String,
    onboardingId: String,
    stories: [StoryViewModel],
    onlyTipJar: Bool,
    accountService: AccountServiceProtocol,
    eventsService: EventsServiceProtocol
  ) {
    self.flow = flow
    self.anonymousId = anonymousId
    self.onboardingId = onboardingId
    self.stories = stories
    self.onlyTipJar = onlyTipJar
    self.accountService = accountService
    self.eventsService = eventsService
  }

  func start() {
    if onlyTipJar {
      self.startTipJar(disclaimer: stories.first?.action?.tipJarDisclaimer)
    } else {
      self.startStories()
    }
  }

  func startStories() {
    let subscriptionService = StoryAccountSubscriptionService(accountService: accountService)
    let viewModel = StoryViewerViewModel(
      subscriptionService: subscriptionService,
      stories: stories
    )

    viewModel.onTransition = { route in
      switch route {
      case .tipJar(let disclaimer):
        Task { @MainActor in
          self.showTipJar(disclaimer: disclaimer)
        }
      case .dismiss:
        self.dismiss()
      case .showAlert(let model):
        self.showAlert(model)
      case .showLoader(let flag):
        if flag {
          self.showLoader()
        } else {
          self.stopLoader()
        }
      case .success:
        self.showCongrats()
      }
    }

    let vc = UIHostingController(rootView: StoryViewer(viewModel: viewModel))
    presentedController = vc
    flow.startPresentation(vc, animated: true)
    eventsService.sendEvent(
      "second_onboarding_start",
      payload: [
        "rc_id": anonymousId,
        "onboarding_id": onboardingId,
      ]
    )
  }

  func dismiss() {
    eventsService.sendEvent(
      "second_onboarding_skip",
      payload: [
        "rc_id": anonymousId,
        "onboarding_id": onboardingId,
      ]
    )
    flow.finishPresentation(animated: true)
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

  func startTipJar(disclaimer: String?) {
    let viewModel = TipJarViewModel(
      disclaimer: disclaimer,
      accountService: accountService
    )

    viewModel.onTransition = { route in
      switch route {
      case .showLoader(let flag):
        if flag {
          self.showLoader()
        } else {
          self.stopLoader()
        }
      case .showAlert(let model):
        self.presentedController?.getTopVisibleViewController()?.showAlert(model)
      case .success(let message):
        self.showCongratsTip(message)
      case .dismiss:
        self.flow.finishPresentation(animated: true)
      }
    }

    let vc = UIHostingController(rootView: TipJarView(viewModel: viewModel))
    presentedController = vc
    flow.startPresentation(vc, animated: true)
    eventsService.sendEvent(
      "second_onboarding_start",
      payload: [
        "rc_id": anonymousId,
        "onboarding_id": onboardingId,
      ]
    )
  }

  func showTipJar(disclaimer: String?) {
    let viewModel = TipJarViewModel(
      disclaimer: disclaimer,
      accountService: accountService
    )

    viewModel.onTransition = { route in
      switch route {
      case .showLoader(let flag):
        if flag {
          self.showLoader()
        } else {
          self.stopLoader()
        }
      case .showAlert(let model):
        self.presentedController?.getTopVisibleViewController()?.showAlert(model)
      case .success(let message):
        self.showCongratsTip(message)
      case .dismiss:
        self.flow.finishPresentation(animated: true)
      }
    }

    let vc = UIHostingController(rootView: TipJarView(viewModel: viewModel))
    vc.modalPresentationStyle = .overFullScreen

    presentedController?.present(vc, animated: true)
  }

  func showCongratsTip(_ message: String) {
    eventsService.sendEvent(
      "second_onboarding_tip",
      payload: [
        "rc_id": anonymousId,
        "onboarding_id": onboardingId,
      ]
    )
    presentedController?.getTopVisibleViewController()?.view.startConfetti()
    presentedController?.getTopVisibleViewController()?.showAlert(message, message: nil) { [weak self] in
      self?.flow.finishPresentation(animated: true)
    }
  }

  func showCongrats() {
    eventsService.sendEvent(
      "second_onboarding_subscription",
      payload: [
        "rc_id": anonymousId,
        "onboarding_id": onboardingId,
      ]
    )
    presentedController?.view.startConfetti()
    presentedController?.showAlert("thanks_amazing_title".localized, message: nil) { [weak self] in
      if self?.accountService.getAccountId() != nil {
        self?.flow.finishPresentation(animated: true)
      } else {
        self?.showCreateProfile()
      }
    }
  }

  func showCreateProfile() {
    let viewModel = LoginViewModel(accountService: accountService)
    viewModel.alertPresenter = self
    viewModel.onTransition = { _ in
      self.flow.finishPresentation(animated: true)
    }

    let vc = UIHostingController(rootView: SupportProfileView(viewModel: viewModel))
    vc.modalPresentationStyle = .overFullScreen
    presentedController?.present(vc, animated: true)
  }
}

