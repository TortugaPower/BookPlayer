//
//  PasskeyRegistrationView.swift
//  BookPlayer
//
//  Created by Claude on 1/9/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

enum PasskeyDestination: Hashable {
  case verifyEmail
  case createPasskey
}

struct PasskeyRegistrationView: View {
  @State private var path = NavigationPath()
  @State private var email: String = ""
  @State private var verificationToken: String = ""
  @State private var loadingState = LoadingOverlayState()
  @State private var showEmailExistsAlert = false

  @Environment(\.dismiss) private var dismiss
  @Environment(\.accountService) private var accountService
  @Environment(\.passkeyService) private var passkeyService
  @EnvironmentObject private var theme: ThemeViewModel

  var onRegistrationComplete: (_ hasSubscription: Bool) -> Void

  var body: some View {
    NavigationStack(path: $path) {
      PasskeyEmailInputView(
        email: $email,
        isLoading: loadingState.show,
        onContinue: sendVerificationCode,
        onSignIn: signInWithPasskey,
        onDismiss: { dismiss() }
      )
      .navigationDestination(for: PasskeyDestination.self) { destination in
        switch destination {
        case .verifyEmail:
          EmailVerificationView(
            email: email,
            onVerified: { token in
              verificationToken = token
              path.append(PasskeyDestination.createPasskey)
              createPasskey()
            }
          )
        case .createPasskey:
          PasskeyCreatingView(email: email)
            .navigationBarBackButtonHidden(true)
        }
      }
    }
    .environment(\.loadingState, loadingState)
    .errorAlert(error: $loadingState.error)
    .loadingOverlay(loadingState.show)
    .alert("passkey_email_exists_title".localized, isPresented: $showEmailExistsAlert) {
      Button("ok_button".localized) {}
    } message: {
      Text("passkey_email_exists_message".localized)
    }
  }

  // MARK: - Actions

  private func signInWithPasskey() {
    Task {
      do {
        loadingState.show = true

        let response = try await passkeyService.signIn()

        try await accountService.handlePasskeyLogin(response: response)

        loadingState.show = false

        onRegistrationComplete(accountService.account.hasSubscription)
      } catch PasskeyError.userCancelled {
        loadingState.show = false
        // User cancelled, stay on screen
      } catch {
        loadingState.show = false
        loadingState.error = error
      }
    }
  }

  private func sendVerificationCode() {
    Task {
      do {
        loadingState.show = true

        _ = try await passkeyService.sendVerificationCode(email: email)

        loadingState.show = false
        path.append(PasskeyDestination.verifyEmail)
      } catch PasskeyError.emailAlreadyRegistered {
        loadingState.show = false
        showEmailExistsAlert = true
      } catch {
        loadingState.show = false
        loadingState.error = error
      }
    }
  }

  private func createPasskey() {
    Task {
      do {
        loadingState.show = true

        let deviceName = UIDevice.current.name
        let response = try await passkeyService.registerNewAccount(
          email: email,
          verificationToken: verificationToken,
          deviceName: deviceName
        )

        // Store token and update account
        try await accountService.handlePasskeyLogin(response: response)

        loadingState.show = false

        onRegistrationComplete(accountService.account.hasSubscription)
      } catch PasskeyError.userCancelled {
        loadingState.show = false
        // Pop to root on cancel
        path = NavigationPath()
      } catch {
        loadingState.show = false
        loadingState.error = error
        // Pop to root on error
        path = NavigationPath()
      }
    }
  }
}

#Preview {
  PasskeyRegistrationView { _ in }
    .environmentObject(ThemeViewModel())
}
