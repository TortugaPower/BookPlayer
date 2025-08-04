//
//  JellyfinServerFoundView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 6/6/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI

enum JellyfinServerFoundViewFields: Focusable {
  case none, username, password
}

struct JellyfinServerFoundView: View {
  @Binding var username: String
  @Binding var password: String

  @State var focusedField: JellyfinServerFoundViewFields = .none

  @EnvironmentObject var theme: ThemeViewModel

  var onCommit: () -> Void = {}

  var body: some View {
    Section {
      ClearableTextField(
        "jellyfin_username_placeholder".localized,
        text: $username,
        onCommit: {
          focusedField = .password
        }
      )
      .textContentType(.username)
      .autocapitalization(.none)
      .focused($focusedField, selfKey: .username)

      SecureField(
        "jellyfin_password_placeholder".localized,
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
      Text("jellyfin_section_login".localized)
        .foregroundStyle(theme.secondaryColor)
    }
    .onAppear {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        focusedField = .username
      }
    }
  }
}
