//
//  AudiobookShelfServerFoundView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/14/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI

enum AudiobookShelfServerFoundViewFields: Focusable {
  case none, username, password
}

struct AudiobookShelfServerFoundView: View {
  @Binding var username: String
  @Binding var password: String

  @State var focusedField: AudiobookShelfServerFoundViewFields = .none

  @EnvironmentObject var theme: ThemeViewModel

  var onCommit: () -> Void = {}

  var body: some View {
    Section {
      ClearableTextField(
        "audiobookshelf_username_placeholder".localized,
        text: $username,
        onCommit: {
          focusedField = .password
        }
      )
      .textContentType(.username)
      .autocapitalization(.none)
      .focused($focusedField, selfKey: .username)

      SecureField(
        "audiobookshelf_password_placeholder".localized,
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
      Text("audiobookshelf_section_login".localized)
        .foregroundStyle(theme.secondaryColor)
    }
    .onAppear {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        focusedField = .username
      }
    }
  }
}
