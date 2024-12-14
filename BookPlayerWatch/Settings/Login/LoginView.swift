//
//  LoginView.swift
//  BookPlayerWatch
//
//  Created by Gianni Carlo on 11/11/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import AuthenticationServices
import BookPlayerWatchKit
import SwiftUI

struct LoginView: View {
  @ForcedEnvironment(\.coreServices) var coreServices
  @Binding var account: Account?
  @State private var isLoading = false
  @State private var error: Error?

  var body: some View {
    VStack(spacing: Spacing.S1) {
      Text("BookPlayer Pro")
        .font(Font(Fonts.titleLarge))
      Text("benefits_watchapp_description".localized)
        .font(Font(Fonts.body))
        .multilineTextAlignment(.center)
      SignInWithAppleButton(.signIn) { request in
        request.requestedScopes = [.email]
      } onCompletion: { result in
        switch result {
        case .success(let authorization):
          Task {
            do {
              isLoading = true

              guard
                let creds = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = creds.identityToken,
                let token = String(data: tokenData, encoding: .utf8)
              else {
                throw AccountError.missingToken
              }

              let account = try await coreServices.accountService.login(
                with: token,
                userId: creds.user
              )

              isLoading = false
              self.account = account
              coreServices.checkAndReloadIfSyncIsEnabled()
            } catch {
              isLoading = false
              self.error = error
            }
          }
        case .failure(let error):
          self.error = error
        }
      }
      .frame(maxHeight: 45)
    }
    .errorAlert(error: $error)
    .overlay {
      Group {
        if isLoading {
          ProgressView()
            .tint(.white)
            .padding()
            .background(
              Color.black
                .opacity(0.9)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            )
        }
      }
    }
  }
}
