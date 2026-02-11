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
  @State private var showPasskeyRegistration = false

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
      .applyListStyle(with: theme, background: theme.systemGroupedBackgroundColor)
      .safeAreaInset(edge: .bottom) {
        Color.clear
          .frame(height: 88)
      }

      VStack(spacing: Spacing.S) {
        AppleSignInLink { hasSubscription in
          handleSignInResult(hasSubscription: hasSubscription)
        }

        // Continue with Passkey - goes to registration/sign-in screen
        ContinueWithPasskeyButton {
          showPasskeyRegistration = true
        }
        .padding(.bottom, Spacing.S)
      }
    }
    .environment(\.loadingState, loadingState)
    .listSectionSpacing(Spacing.S2)
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
    .sheet(isPresented: $showPasskeyRegistration) {
      PasskeyRegistrationView { hasSubscription in
        showPasskeyRegistration = false
        handleSignInResult(hasSubscription: hasSubscription)
      }
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

  private func handleSignInResult(hasSubscription: Bool) {
    if hasSubscription {
      dismiss()
    } else {
      showCompleteAccount = true
    }
  }
}

#Preview {
  NavigationStack {
    LoginView()
  }
  .environmentObject(ThemeViewModel())
}
