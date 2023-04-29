//
//  BPAlertContent.swift
//  BookPlayer
//
//  Created by gianni.carlo on 20/2/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import Foundation
import UIKit

struct BPAlertContent {
  let title: String?
  let message: String?
  let style: UIAlertController.Style
  let textInputPlaceholder: String?
  let actionItems: [BPActionItem]

  init(
    title: String? = nil,
    message: String? = nil,
    style: UIAlertController.Style,
    textInputPlaceholder: String? = nil,
    actionItems: [BPActionItem]
  ) {
    self.title = title
    self.message = message
    self.style = style
    self.textInputPlaceholder = textInputPlaceholder
    self.actionItems = actionItems
  }
}

extension BPAlertContent {
  static func errorAlert(title: String = "error_title".localized, message: String) -> BPAlertContent {
    return BPAlertContent(
      title: title,
      message: message,
      style: .alert,
      actionItems: [BPActionItem(title: "ok_button".localized)]
    )
  }
}

struct BPActionItem {
  let title: String
  let style: UIAlertAction.Style
  let isEnabled: Bool
  let handler: () -> Void
  var inputHandler: ((String) -> Void)?

  init(
    title: String,
    style: UIAlertAction.Style = .default,
    isEnabled: Bool = true,
    handler: @escaping () -> Void = {},
    inputHandler: ((String) -> Void)? = nil
  ) {
    self.title = title
    self.style = style
    self.isEnabled = isEnabled
    self.handler = handler
    self.inputHandler = inputHandler
  }
}

extension BPActionItem {
  static var cancelAction = BPActionItem(
    title: "cancel_button".localized,
    style: .cancel,
    isEnabled: true,
    handler: {},
    inputHandler: nil
  )
}
