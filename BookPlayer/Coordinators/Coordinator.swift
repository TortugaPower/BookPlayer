//
//  Coordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/9/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import UIKit

public typealias BPTransition<T> = ((T) -> Void)

protocol Coordinator: AnyObject {
  var flow: BPCoordinatorPresentationFlow { get }
  func start()
}

extension AlertPresenter where Self: Coordinator {
  func showAlert(_ title: String? = nil, message: String? = nil, completion: (() -> Void)? = nil) {
    flow.navigationController.showAlert(title, message: message, completion: completion)
  }

  func showAlert(_ content: BPAlertContent) {
    flow.navigationController.showAlert(content)
  }

  func showLoader() {
    LoadingUtils.loadAndBlock(in: flow.navigationController)
  }

  func stopLoader() {
    LoadingUtils.stopLoading(in: flow.navigationController)
  }
}
