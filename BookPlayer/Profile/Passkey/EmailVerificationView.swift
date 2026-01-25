//
//  EmailVerificationView.swift
//  BookPlayer
//
//  Created by Claude on 1/11/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct EmailVerificationView: View {
  let email: String
  var onVerified: (String) -> Void

  @State private var code: String = ""
  @FocusState private var isTextFieldFocused: Bool
  @State private var resendCooldown: Int = 0

  @Environment(\.loadingState) private var loadingState
  @Environment(\.passkeyService) private var passkeyService
  @EnvironmentObject private var theme: ThemeViewModel

  private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

  var body: some View {
    VStack(spacing: Spacing.S) {
      Text(String(format: "verify_email_subtitle".localized, email))
        .bpFont(Fonts.subheadline)
        .foregroundStyle(theme.primaryColor)
        .multilineTextAlignment(.center)

      ClearableTextField("", text: $code) {
        verifyCode()
      }
      .keyboardType(.numberPad)
      .textContentType(.oneTimeCode)
      .autocapitalization(.none)
      .focused($isTextFieldFocused)
      .padding(.vertical, Spacing.M)

      // Verify button
      PrimaryButton(text: "verify_button".localized) {
        verifyCode()
      }
      .disabled(code.isEmpty || loadingState.show)

      // Resend section
      VStack(spacing: Spacing.S4) {
        Text("verify_didnt_receive".localized)
          .bpFont(Fonts.caption)
          .foregroundStyle(theme.secondaryColor)

        if resendCooldown > 0 {
          Text(String(format: "verify_resend_wait".localized, resendCooldown))
            .bpFont(Fonts.caption)
            .foregroundStyle(theme.secondaryColor)
        } else {
          Button("verify_resend_button".localized) {
            resendCode()
          }
          .bpFont(Fonts.caption)
          .foregroundStyle(theme.linkColor)
          .disabled(loadingState.show)
        }
      }
      Spacer()
    }
    .padding(.horizontal, Spacing.M)
    .onReceive(timer) { _ in
      if resendCooldown > 0 {
        resendCooldown -= 1
      }
    }
    .onAppear {
      isTextFieldFocused = true
    }
    .applyListStyle(with: theme, background: theme.systemGroupedBackgroundColor)
    .navigationTitle("verify_email_title".localized)
    .navigationBarTitleDisplayMode(.inline)
  }

  private func verifyCode() {
    guard !code.isEmpty, !loadingState.show else { return }

    loadingState.show = true

    Task {
      do {
        let response = try await passkeyService.checkVerificationCode(
          email: email,
          code: code
        )

        loadingState.show = false

        if let token = response.verificationToken {
          onVerified(token)
        } else {
          loadingState.error = PasskeyError.emailVerificationFailed(
            response.message ?? "Verification failed"
          )
        }
      } catch {
        loadingState.show = false
        loadingState.error = error
        // Clear code on error
        code = ""
        isTextFieldFocused = true
      }
    }
  }

  private func resendCode() {
    guard !loadingState.show else { return }

    loadingState.show = true

    Task {
      do {
        _ = try await passkeyService.sendVerificationCode(email: email)
        loadingState.show = false
        resendCooldown = 60  // Wait 60 seconds before allowing resend
        code = ""
        isTextFieldFocused = true
      } catch {
        loadingState.show = false
        loadingState.error = error
      }
    }
  }
}

#Preview {
  NavigationStack {
    EmailVerificationView(
      email: "test@example.com",
      onVerified: { _ in }
    )
  }
  .environmentObject(ThemeViewModel())
}
