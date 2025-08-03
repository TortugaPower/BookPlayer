//
//  AccountManageProSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import RevenueCat
import SwiftUI

struct AccountManageProSectionView: View {
  @Environment(\.loadingState) private var loadingState
  @EnvironmentObject private var theme: ThemeViewModel
  var body: some View {
    Section {
      Button {
        guard !ProcessInfo.processInfo.isiOSAppOnMac else {
          loadingState.error = AccountError.managementUnavailable
          return
        }

        loadingState.show = true
        Task {
          do {
            try await Purchases.shared.showManageSubscriptions()
            loadingState.show = false
          } catch {
            loadingState.show = false
            loadingState.error = error
          }
        }
      } label: {
        Label {
          Text("BookPlayer Pro")
            .foregroundStyle(theme.primaryColor)
        } icon: {
          Image(systemName: "icloud.and.arrow.up.fill")
            .foregroundStyle(theme.linkColor)
        }
      }
    }
  }
}

#Preview {
  AccountManageProSectionView()
    .environmentObject(ThemeViewModel())
}
