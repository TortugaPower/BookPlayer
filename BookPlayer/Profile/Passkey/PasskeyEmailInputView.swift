//
//  PasskeyEmailInputView.swift
//  BookPlayer
//
//  Created by Claude on 1/17/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct PasskeyEmailInputView: View {
  @Binding var email: String
  let isLoading: Bool
  let onContinue: () -> Void
  let onSignIn: () -> Void
  let onDismiss: () -> Void

  @FocusState private var isTextFieldFocused: Bool
  @EnvironmentObject private var theme: ThemeViewModel

  private var isEmailValid: Bool {
    let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
  }

  var body: some View {
    Form {
      Section {
        ClearableTextField(
          "email_title".localized,
          text: $email,
          onCommit: {
            isTextFieldFocused = false
          }
        )
        .textContentType(.emailAddress)
        .keyboardType(.emailAddress)
        .autocapitalization(.none)
        .disableAutocorrection(true)
        .focused($isTextFieldFocused)
        .onAppear {
          isTextFieldFocused = true
        }
      } header: {
        Text("email_title".localized)
          .foregroundStyle(theme.secondaryColor)
      }

      Section {
        PrimaryButton(text: "continue_title".localized) {
          onContinue()
        }
        .disabled(!isEmailValid || isLoading)

        Button(action: onSignIn) {
          Text("passkey_signin_existing".localized)
            .bpFont(Fonts.body)
            .frame(maxWidth: .infinity)
            .foregroundColor(theme.linkColor)
        }
        .buttonStyle(.borderless)
        .tint(theme.linkColor)
      }
      .listRowSeparator(.hidden)
      .listRowBackground(Color.clear)
    }
    .contentShape(Rectangle())
    .onTapGesture {
      isTextFieldFocused = false
    }
    .navigationTitle("passkey_registration_title".localized)
    .navigationBarTitleDisplayMode(.inline)
    .applyListStyle(with: theme, background: theme.systemGroupedBackgroundColor)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button {
          onDismiss()
        } label: {
          Image(systemName: "xmark")
            .foregroundStyle(theme.linkColor)
        }
      }
    }
  }
}

#Preview {
  NavigationStack {
    PasskeyEmailInputView(
      email: .constant(""),
      isLoading: false,
      onContinue: {},
      onSignIn: {},
      onDismiss: {}
    )
  }
  .environmentObject(ThemeViewModel())
}
