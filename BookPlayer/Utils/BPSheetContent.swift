//
//  BPSheetContent.swift
//  BookPlayer
//
//  Created by gianni.carlo on 25/2/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import Foundation

typealias BPActionItem = (title: String, handler: () -> Void)
struct BPSheetContent {
  let title: String?
  let message: String?
  let actionItems: [BPActionItem]
  let cancelTextButton: String?
  let cancelAction: () -> Void

  init(
    title: String? = nil,
    message: String? = nil,
    actionItems: [BPActionItem],
    cancelTextButton: String = "cancel_button".localized,
    cancelAction: @escaping () -> Void = {}
  ) {
    self.title = title
    self.message = message
    self.actionItems = actionItems
    self.cancelTextButton = cancelTextButton
    self.cancelAction = cancelAction
  }
}
