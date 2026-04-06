//
//  IntegrationDisconnectedView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/5/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

private enum DisconnectedViewFields: Focusable {
  case none, serverUrl
}

struct IntegrationDisconnectedView: View {
  @Binding var serverUrl: String

  let placeholderURL: String
  let integrationName: String

  @State private var focusedField: DisconnectedViewFields = .none

  @EnvironmentObject var theme: ThemeViewModel

  var onCommit: () -> Void = {}

  var body: some View {
    ThemedSection {
      ClearableTextField(
        placeholderURL,
        text: $serverUrl,
        onCommit: {
          if !serverUrl.isEmpty {
            onCommit()
          }
        }
      )
      .keyboardType(.URL)
      .textContentType(.URL)
      .textInputAutocapitalization(.never)
      .focused($focusedField, selfKey: .serverUrl)
    } header: {
      Text("integration_section_server_url".localized)
        .foregroundStyle(theme.secondaryColor)
    } footer: {
      Text(
        String(
          format: "integration_section_server_url_footer".localized,
          integrationName
        )
      )
      .foregroundStyle(theme.secondaryColor)
    }
    .onAppear {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        focusedField = .serverUrl
      }
    }
  }
}
