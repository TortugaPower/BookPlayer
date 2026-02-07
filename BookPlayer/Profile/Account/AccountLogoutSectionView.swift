//
//  AccountLogoutSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct AccountLogoutSectionView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.loadingState) private var loadingState
  @Environment(\.accountService) private var accountService

  @EnvironmentObject private var theme: ThemeViewModel

  var body: some View {
    ThemedSection {
      Button {
        do {
          try accountService.logout()
          dismiss()
        } catch {
          loadingState.error = error
        }
      } label: {
        Label {
          Text("logout_title")
            .bpFont(.body)
            .foregroundStyle(theme.primaryColor)
        } icon: {
          Image(systemName: "rectangle.portrait.and.arrow.forward")
            .foregroundStyle(.red)
        }
      }
    }
  }
}

#Preview {
  AccountLogoutSectionView()
    .environmentObject(ThemeViewModel())
}
