//
//  BPAlertContent.swift
//  BookPlayer
//
//  Created by gianni.carlo on 20/2/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import Foundation

struct BPAlertContent {
  let title: String?
  let message: String?
  let textButton: String
  let cancelTextButton: String?
  let cancelAction: () -> Void
  let confirmationAction: () -> Void

  init(
    title: String? = nil,
    message: String? = nil,
    textButton: String = "ok_button".localized,
    confirmationAction: @escaping () -> Void = {}
  ) {
    self.title = title
    self.message = message
    self.textButton = textButton
    self.cancelTextButton = nil
    self.cancelAction = {}
    self.confirmationAction = confirmationAction
  }

  init(
    title: String? = nil,
    message: String? = nil,
    textButton: String = "ok_button".localized,
    cancelTextButton: String = "cancel_button".localized,
    cancelAction: @escaping () -> Void = {},
    confirmationAction: @escaping () -> Void
  ) {
    self.title = title
    self.message = message
    self.textButton = textButton
    self.cancelTextButton = cancelTextButton
    self.cancelAction = cancelAction
    self.confirmationAction = confirmationAction
  }
}
