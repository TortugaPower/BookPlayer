//
//  LoginSignInButton.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 1/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import AuthenticationServices
import BookPlayerKit
import SwiftUI

struct LoginSignInButton: View {
  @Environment(\.loadingState) private var loadingState
  @Environment(\.accountService) private var accountService
  @EnvironmentObject private var theme: ThemeViewModel

  var handleSignIn: (_ hasSubscription: Bool) -> Void

  var body: some View {
    SignInWithAppleButton(.signIn) { request in
      request.requestedScopes = [.email]
    } onCompletion: { result in
      switch result {
      case .success(let authorization):
        Task {
          do {
            loadingState.show = true

            guard
              let creds = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = creds.identityToken,
              let token = String(data: tokenData, encoding: .utf8)
            else {
              throw AccountError.missingToken
            }

            let account = try await accountService.login(
              with: token,
              userId: creds.user
            )

            loadingState.show = false

            handleSignIn(account?.hasSubscription == true)
          } catch {
            loadingState.show = false
            loadingState.error = error
          }
        }
      case .failure(let error):
        loadingState.error = error
      }
    }
    .frame(height: 46)
    .signInWithAppleButtonStyle(theme.useDarkVariant ? .white : .black)
    /// Apple's default corner radius is its own, not a house choice — clipping it to the same
    /// capsule the rest of our buttons use keeps one shape language on these screens.
    .clipShape(Capsule())
    .padding(.vertical)
    .padding(.horizontal, Spacing.M)
  }
}

#Preview {
  LoginSignInButton { _ in }
}
