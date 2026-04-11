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
          title: "Bring Your Own Server",
          subtitle: "Connect your existing Jellyfin, Audiobookshelf, or other external libraries directly to the app."
        )
        
        // Feature 2: Streaming (No Local Storage)
        LoginBenefitSectionView(
          imageName: "waveform",
          title: "Stream & Save Space",
          subtitle: "Listen instantly by streaming directly from your source. No need to download files or use up local storage."
        )
        
        // Feature 3: Two-Way Sync
        LoginBenefitSectionView(
          imageName: "arrow.triangle.2.circlepath",
          title: "Two-Way Progress Sync",
          subtitle: "Your listening progress stays perfectly synced with your server and across all your devices."
        )
        
        // Feature 4: Cheaper Tier Value
        LoginBenefitSectionView(
          imageName: "tag.fill", // Or "dollarsign.circle"
          title: "More Affordable Sync",
          subtitle: "Get all the power of cloud synchronization at a fraction of the cost by leveraging your own media servers."
        )
        
        LoginDisclaimerSectionView()
      }
      .applyListStyle(with: theme, background: theme.systemGroupedBackgroundColor)
      .safeAreaInset(edge: .bottom) {
        Color.clear
          .frame(height: 88)
      }
      
      // Bottom Call-to-Action Area
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
            Text("View Subscription Options")
              .font(.headline)
              .foregroundColor(.white)
              .frame(maxWidth: .infinity)
              .padding()
              .background(theme.systemBackgroundColor) // Or whatever your primary button color is
              .cornerRadius(12)
          }
          .padding(.horizontal)
          .padding(.bottom, Spacing.S)
        }
      }
    }
    .listSectionSpacing(Spacing.S2)
    .navigationTitle("Stream & Sync")
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
