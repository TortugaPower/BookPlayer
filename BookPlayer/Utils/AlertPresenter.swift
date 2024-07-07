//
//  AlertPresenter.swift
//  BookPlayer
//
//  Created by gianni.carlo on 27/5/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation

protocol AlertPresenter: AnyObject {
  func showAlert(_ title: String?, message: String?, completion: (() -> Void)?)
  func showLoader()
  func stopLoader()
}

/// Empty implementation of `AlertPresenter`
/// - Note: the need of this means that the `AppDelegate.loadPlayer` could benefit from having an async version
/// so we don't need to pass an `AlertPresenter` as a parameter
class VoidAlertPresenter: AlertPresenter {
  func showAlert(_ title: String?, message: String?, completion: (() -> Void)?) {}

  func showLoader() {}

  func stopLoader() {}
}
