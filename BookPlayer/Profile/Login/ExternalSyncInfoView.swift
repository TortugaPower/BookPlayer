//
//  ExternalSyncInfoView.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 9/4/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI
import AuthenticationServices
import BookPlayerKit

struct ExternalSyncIntroView: View {
  @EnvironmentObject private var theme: ThemeViewModel
  @Environment(\.dismiss) private var dismiss
  
  // State to trigger your subscription tiers presentation
  @State private var loadingState = LoadingOverlayState()
  @State private var showCompleteAccount = false
  @State private var showPasskeyRegistration = false
  @Environment(\.accountService) private var accountService
  
  var body: some View {
    ZStack(alignment: .bottom) {
      Form {
        // Feature 1: External Server Connection
        LoginBenefitSectionView(
          imageName: "server.rack",
          title: "external_sync_benefit_server_title",
          subtitle: "external_sync_benefit_server_subtitle"
        )
        
        // Feature 2: Streaming (No Local Storage)
        LoginBenefitSectionView(
          imageName: "waveform",
          title: "external_sync_benefit_stream_title",
          subtitle: "external_sync_benefit_stream_subtitle"
        )
        
        // Feature 3: Two-Way Sync
        LoginBenefitSectionView(
          imageName: "arrow.triangle.2.circlepath",
          title: "external_sync_benefit_sync_title",
          subtitle: "external_sync_benefit_sync_subtitle"
        )
        
        LoginDisclaimerSectionView()
      }
      .applyListStyle(with: theme, background: theme.systemGroupedBackgroundColor)
      .safeAreaInset(edge: .bottom) {
        VStack(spacing: Spacing.S) {
          if accountService.account.id.isEmpty {
            AppleSignInLink { hasSubscription in
              handleSignInResult(hasSubscription: hasSubscription)
            }

            // Continue with Passkey - goes to registration/sign-in screen
            ContinueWithPasskeyButton {
              showPasskeyRegistration = true
            }
            .padding(.bottom, Spacing.S)
          } else {
            Button {
              showCompleteAccount = true
            } label: {
              Text("continue_title".localized)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(theme.linkColor) // Or whatever your primary button color is
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, Spacing.S)
          }
        }
      }
    }
    .listSectionSpacing(Spacing.S2)
    .navigationTitle("external_sync_info_title".localized)
    .navigationBarTitleDisplayMode(.inline)
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
