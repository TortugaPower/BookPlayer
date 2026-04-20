//
//  IntegrationCustomHeadersSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/20/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct IntegrationCustomHeadersSectionView: View {
  @Binding var customHeaders: [CustomHeaderEntry]

  /// Called whenever headers change in the `.connected` state so the caller can persist them.
  /// When nil, edits are only held in-memory on the form (e.g. during initial connect/sign-in).
  var onCommit: (() -> Void)?

  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    ThemedSection {
      ForEach($customHeaders) { $entry in
        VStack(alignment: .leading, spacing: 4) {
          TextField(
            "integration_custom_headers_key_placeholder".localized,
            text: $entry.key
          )
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .textContentType(.oneTimeCode)

          TextField(
            "integration_custom_headers_value_placeholder".localized,
            text: $entry.value
          )
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .textContentType(.oneTimeCode)
        }
        .padding(.vertical, 2)
      }
      .onDelete { indices in
        customHeaders.remove(atOffsets: indices)
      }

      Button {
        customHeaders.append(CustomHeaderEntry())
      } label: {
        Label(
          "integration_custom_headers_add_button".localized,
          systemImage: "plus.circle"
        )
        .foregroundStyle(theme.linkColor)
      }
    } header: {
      Text("integration_custom_headers_title".localized)
        .foregroundStyle(theme.secondaryColor)
    } footer: {
      Text("integration_custom_headers_footer".localized)
        .foregroundStyle(theme.secondaryColor)
    }
    .onChange(of: customHeaders) {
      onCommit?()
    }
  }
}
