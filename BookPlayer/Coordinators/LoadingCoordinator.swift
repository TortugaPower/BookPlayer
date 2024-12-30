//
//  LoadingCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/9/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import UIKit

class LoadingCoordinator: Coordinator, AlertPresenter {
  let flow: BPCoordinatorPresentationFlow
  var mainCoordinator: MainCoordinator?

  init(flow: BPCoordinatorPresentationFlow) {
    self.flow = flow
  }

  func start() {
    let viewModel = LoadingViewModel()
    viewModel.coordinator = self
    let vc = LoadingViewController.instantiate(from: .Main)
    vc.viewModel = viewModel
    flow.startPresentation(vc, animated: false)
  }

  func didFinishLoadingSequence() {
    let coreServices = AppDelegate.shared!.coreServices!

    let coordinator = MainCoordinator(
      navigationController: flow.navigationController,
      coreServices: coreServices
    )
    mainCoordinator = coordinator

    coordinator.start()
  }

  func getMainCoordinator() -> MainCoordinator? {
    return mainCoordinator
  }
}
