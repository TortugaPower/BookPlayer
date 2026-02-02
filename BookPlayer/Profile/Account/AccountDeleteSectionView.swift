//
//  AccountDeleteSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct AccountDeleteSectionView: View {
  @Binding var showAlert: Bool

  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    Section {
      Button {
        showAlert = true
      } label: {
        Label {
          Text("delete_account_title")
            .bpFont(.body)
            .foregroundStyle(theme.primaryColor)
        } icon: {
          Image(systemName: "trash")
            .foregroundStyle(.red)
        }
      }
    }
  }
}
