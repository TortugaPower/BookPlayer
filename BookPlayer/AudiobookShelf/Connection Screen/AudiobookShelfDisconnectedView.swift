//
//  AudiobookShelfDisconnectedView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/14/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI

enum AudiobookShelfDisconnectedViewFields: Focusable {
  case none, serverUrl
}

struct AudiobookShelfDisconnectedView: View {
  @Binding var serverUrl: String

  @State var focusedField: AudiobookShelfDisconnectedViewFields = .none

  @EnvironmentObject var theme: ThemeViewModel

  var onCommit: () -> Void = {}

  var body: some View {
    Section {
      ClearableTextField(
        "http://audiobookshelf.example.com",
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
      Text("audiobookshelf_section_server_url".localized)
        .foregroundStyle(theme.secondaryColor)
    } footer: {
      Text("audiobookshelf_section_server_url_footer".localized)
        .foregroundStyle(theme.secondaryColor)
    }
    .onAppear {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        focusedField = .serverUrl
      }
    }
  }
}
