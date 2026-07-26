//
//  IntegrationServerFoundView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/5/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

private enum ServerFoundViewFields: Focusable {
  case none, username, password
}

struct IntegrationServerFoundView: View {
  @Binding var username: String
  @Binding var password: String

  @State private var focusedField: ServerFoundViewFields = .none

  @EnvironmentObject var theme: ThemeViewModel

  /// Suppresses the automatic focus on the username field. Set when an alternative sign-in method is
  /// offered above: raising the keyboard immediately presumes the user wants to type credentials, and
  /// it covers the SSO option they may have come here to use.
  var autoFocusesUsername: Bool = true

  var onCommit: () -> Void = {}

  var body: some View {
    ThemedSection {
      ClearableTextField(
        "integration_username_placeholder".localized,
        text: $username,
        onCommit: {
          focusedField = .password
        }
      )
      .textContentType(.username)
      .textInputAutocapitalization(.never)
      .focused($focusedField, selfKey: .username)

      SecureField(
        "integration_password_placeholder".localized,
        text: $password,
        onCommit: {
          if !username.isEmpty && !password.isEmpty {
            onCommit()
          }
        }
      )
      .textContentType(.password)
      .focused($focusedField, selfKey: .password)
    } header: {
      Text("integration_section_login".localized)
        .foregroundStyle(theme.secondaryColor)
    }
    .onAppear {
      guard autoFocusesUsername else { return }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        focusedField = .username
      }
    }
  }
}
