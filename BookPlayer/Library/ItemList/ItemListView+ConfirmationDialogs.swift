//
//  ItemListView+ConfirmationDialogs.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/10/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

// MARK: - Confirmation Dialog Content Builders
extension ItemListView {
  func confirmationDialogTitle(for dialog: ConfirmationDialogType) -> String {
    switch dialog {
    case .itemOptions:
      let isSingle = model.selectedItems.count == 1
      return isSingle ? (model.selectedItems.first?.title ?? "") : "options_button".localized
    case .addOptions:
      return "import_description".localized
    }
  }
  
  @ViewBuilder
  func confirmationDialogContent(for dialog: ConfirmationDialogType) -> some View {
    switch dialog {
    case .itemOptions:
      itemOptionsDialog()
    case .addOptions:
      addFilesOptions()
      Button("cancel_button", role: .cancel) {}
    }
  }
}
