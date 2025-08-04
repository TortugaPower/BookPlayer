//
//  LoginView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 1/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import AuthenticationServices
import BookPlayerKit
import SwiftUI

struct LoginView: View {
  @State private var loadingState = LoadingOverlayState()
  @State private var showCompleteAccount = false

  @EnvironmentObject private var theme: ThemeViewModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ZStack(alignment: .bottom) {
      Form {
        LoginBenefitSectionView(
          imageName: "icloud.and.arrow.up.fill",
          title: "benefits_cloudsync_title",
          subtitle: "benefits_cloudsync_description"
        )
        LoginBenefitSectionView(
          imageName: "applewatch.radiowaves.left.and.right",
          title: "Apple Watch (Beta)",
          subtitle: "benefits_watchapp_description"
        )
        LoginBenefitSectionView(
          imageName: "paintpalette.fill",
          title: "benefits_themesicons_title",
          subtitle: "benefits_themesicons_description"
        )
        LoginDisclaimerSectionView()
      }
      .contentMargins(.top, Spacing.S1, for: .scrollContent)
      .safeAreaInset(edge: .bottom) {
        Spacer().frame(height: 88)
      }
      LoginSignInButton { hasSubscription in
        if hasSubscription {
          dismiss()
        } else {
          showCompleteAccount = true
        }
      }
    }
    .environment(\.loadingState, loadingState)
    .toolbarColorScheme(theme.useDarkVariant ? .dark : .light, for: .navigationBar)
    .listSectionSpacing(Spacing.S2)
    .scrollContentBackground(.hidden)
    .navigationTitle("BookPlayer Pro")
    .navigationBarTitleDisplayMode(.inline)
    .errorAlert(error: $loadingState.error)
    .loadingOverlay(loadingState.show)
    .sheet(isPresented: $showCompleteAccount) {
      NavigationStack {
        CompleteAccountView {
          dismiss()
        }
      }
      .presentationDetents([.medium])
    }
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button {
          dismiss()
        } label: {
          Image(systemName: "xmark")
            .foregroundStyle(theme.linkColor)
        }
      }
    }
  }
}

#Preview {
  NavigationStack {
    LoginView()
  }
  .environmentObject(ThemeViewModel())
}
