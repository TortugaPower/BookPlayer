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
    /// The buttons ARE the inset, so the list reserves exactly their height. This used to
    /// reserve a hardcoded 88pt and overlay the stack as a ZStack sibling — but the stack is
    /// nearer 100pt before Dynamic Type touches it, so the last disclaimer line could not be
    /// scrolled clear of the buttons on a short screen. The opaque background matters as much:
    /// `AppleSignInLink` is an opaque pill and hides what passes behind it, while
    /// `ContinueWithPasskeyButton` is bare text, so the disclaimer used to scroll straight
    /// through it.
    .safeAreaInset(edge: .bottom) {
      VStack(spacing: Spacing.S) {
        AppleSignInLink { hasSubscription in
          handleSignInResult(hasSubscription: hasSubscription)
        }

        /// Goes to the registration/sign-in screen
        ContinueWithPasskeyButton {
          showPasskeyRegistration = true
        }
        .padding(.bottom, Spacing.S)
      }
      .background(theme.systemGroupedBackgroundColor)
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
