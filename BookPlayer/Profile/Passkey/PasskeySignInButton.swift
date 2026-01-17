//
//  PasskeySignInButton.swift
//  BookPlayer
//
//  Created by Claude on 1/9/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct PasskeySignInButton: View {
  @Environment(\.loadingState) private var loadingState
  @Environment(\.accountService) private var accountService
  @Environment(\.passkeyService) private var passkeyService
  @EnvironmentObject private var theme: ThemeViewModel

  var handleSignIn: (_ hasSubscription: Bool) -> Void

  var body: some View {
    Button(action: signIn) {
      HStack(spacing: Spacing.S) {
        Image(systemName: "person.badge.key.fill")
          .font(.title2)
        Text("passkey_signin_button".localized)
          .font(.headline)
      }
      .frame(maxWidth: .infinity)
      .frame(height: 46)
      .background(theme.useDarkVariant ? Color.white : Color.black)
      .foregroundColor(theme.useDarkVariant ? .black : .white)
      .cornerRadius(8)
    }
    .padding(.horizontal, Spacing.M)
  }

  private func signIn() {
    Task {
      do {
        loadingState.show = true

        let response = try await passkeyService.signIn()

        // Store token and update account
        try await accountService.handlePasskeyLogin(response: response)

        loadingState.show = false

        handleSignIn(accountService.account.hasSubscription)
      } catch PasskeyError.userCancelled {
        loadingState.show = false
        // User cancelled, no error to show
      } catch {
        loadingState.show = false
        loadingState.error = error
      }
    }
  }
}

#Preview {
  PasskeySignInButton { _ in }
    .environmentObject(ThemeViewModel())
}
