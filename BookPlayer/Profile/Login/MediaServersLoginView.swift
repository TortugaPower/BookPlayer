//
//  MediaServersLoginView.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 9/4/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import AuthenticationServices
import BookPlayerKit
import SwiftUI

/// The media-server half of the sign-up funnel, presented when someone without the entitlement
/// asks to stream. `LoginView` is its sibling: same benefit rows and the same sign-in buttons,
/// but it pitches cloud sync and ends on `.pro`, where this pitches the server features and
/// ends on `.lite`.
struct MediaServersLoginView: View {
  @EnvironmentObject private var theme: ThemeViewModel
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accountService) private var accountService

  @State private var loadingState = LoadingOverlayState()
  @State private var showCompleteAccount = false
  @State private var showPasskeyRegistration = false

  var body: some View {
    Form {
      /// No "bring your own server" row: this screen is only reachable from inside a connected
      /// browser, and connecting a server is free anyway — pitching it on a paywall reads as
      /// charging for something the user already has.
      LoginBenefitSectionView(
        imageName: "waveform",
        title: "external_sync_benefit_stream_title",
        subtitle: "external_sync_benefit_stream_subtitle"
      )

      LoginBenefitSectionView(
        imageName: "arrow.clockwise.icloud",
        title: "external_sync_benefit_sync_title",
        subtitle: "external_sync_benefit_sync_subtitle"
      )

      LoginDisclaimerSectionView()
    }
    .applyListStyle(with: theme, background: theme.systemGroupedBackgroundColor)
    /// The buttons ARE the inset, so the list reserves exactly their height — `LoginView` does
    /// this with a spacer of a hardcoded 88pt and a sibling overlay instead.
    .safeAreaInset(edge: .bottom) {
      VStack(spacing: Spacing.S) {
        if accountService.account.id.isEmpty {
          AppleSignInLink { hasSubscription in
            handleSignInResult(hasSubscription: hasSubscription)
          }

          /// Goes to the registration/sign-in screen
          ContinueWithPasskeyButton {
            showPasskeyRegistration = true
          }
          .padding(.bottom, Spacing.S)
        } else {
          Button {
            showCompleteAccount = true
          } label: {
            Text("continue_title")
              .font(.headline)
              .foregroundColor(.white)
              .frame(maxWidth: .infinity)
              .padding()
              .background(theme.linkColor)
              .cornerRadius(12)
          }
          .padding(.horizontal)
          .padding(.bottom, Spacing.S)
        }
      }
    }
    /// Load-bearing: `AppleSignInLink` reads `\.loadingState` from the environment and writes
    /// its progress and its errors there. Without the injection it would write into the
    /// `@Entry` placeholder, and a failed sign-in would be swallowed with nothing on screen.
    .environment(\.loadingState, loadingState)
    .listSectionSpacing(Spacing.S2)
    .navigationTitle("external_sync_info_title")
    .navigationBarTitleDisplayMode(.inline)
    .errorAlert(error: $loadingState.error)
    .loadingOverlay(loadingState.show)
    /// Presented as a sheet, so there is no back button to fall back on
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button {
          dismiss()
        } label: {
          Image(systemName: "xmark")
            .foregroundStyle(theme.linkColor)
        }
        .accessibilityLabel("close_title")
      }
    }
    .sheet(isPresented: $showCompleteAccount) {
      NavigationStack {
        CompleteAccountView(subType: .lite) {
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
    MediaServersLoginView()
  }
  .environmentObject(ThemeViewModel())
}
