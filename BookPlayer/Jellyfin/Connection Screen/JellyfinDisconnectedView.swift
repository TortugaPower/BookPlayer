//
//  JellyfinDisconnectedView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 6/6/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI

enum JellyfinDisconnectedViewFields: Focusable {
  case none, serverUrl
}

struct JellyfinDisconnectedView: View {
  @Binding var serverUrl: String

  @State var focusedField: JellyfinDisconnectedViewFields = .none

  @EnvironmentObject var theme: ThemeViewModel

  var onCommit: () -> Void = {}

  var body: some View {
    Section {
      ClearableTextField(
        "http://jellyfin.example.com:8096",
        text: $serverUrl,
        onCommit: {
          if !serverUrl.isEmpty {
            onCommit()
          }
        }
      )
      .keyboardType(.URL)
      .textContentType(.URL)
      .autocapitalization(.none)
      .focused($focusedField, selfKey: .serverUrl)
    } header: {
      Text("jellyfin_section_server_url".localized)
        .foregroundStyle(theme.secondaryColor)
    } footer: {
      Text("jellyfin_section_server_url_footer".localized)
        .foregroundStyle(theme.secondaryColor)
    }
    .onAppear {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        focusedField = .serverUrl
      }
    }
  }
}
