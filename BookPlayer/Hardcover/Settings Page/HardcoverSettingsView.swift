//
//  HardcoverSettingsView.swift
//  BookPlayer
//
//  Created by Jeremy Grenier on 6/27/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct HardcoverSettingsView: View {
  @Environment(\.dismiss) var dismiss
  @StateObject var themeViewModel = ThemeViewModel()

  @StateObject var viewModel: HardcoverSettingsView.Model

  @FocusState private var isTextFieldFocused: Bool

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField(
            "Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXV…",
            text: $viewModel.accessToken
          )
          .foregroundColor(themeViewModel.primaryColor)
          .autocapitalization(.none)
          .autocorrectionDisabled()
          .focused($isTextFieldFocused)
          .submitLabel(.done)
          .onSubmit {
            isTextFieldFocused = false
          }
        } header: {
          Text("API Access".localized)
            .foregroundColor(themeViewModel.secondaryColor)
        } footer: {
          if let attributedString = try? AttributedString(markdown: "Your can find your Hardcover API access at https://hardcover.app/account/api.".localized) {
            Text(attributedString)
              .foregroundColor(themeViewModel.secondaryColor)
          }
        }
        .navigationBarTitleDisplayMode(.inline)
      }
      .toolbar {
        navigationBar
      }
    }
    .environmentObject(themeViewModel)
  }

  @ToolbarContentBuilder
  var navigationBar: some ToolbarContent {
      ToolbarItem(placement: .principal) {
        Text("Hardcover Settings")
          .font(.headline)
          .foregroundColor(themeViewModel.primaryColor)
      }
      ToolbarItemGroup(placement: .cancellationAction) {
        Button(
          action: {
            dismiss()
          },
          label: {
            Image(systemName: "xmark")
              .foregroundColor(themeViewModel.linkColor)
          })
      }
    ToolbarItemGroup(placement: .confirmationAction) {
      Button(
        "Save".localized,
        action: {
          viewModel.onSaveTapped()
        }
      )
      .disabled(!viewModel.isSaveEnabled)
    }
  }
}

extension HardcoverSettingsView {
  class Model: ObservableObject {
    @Published var accessToken: String
    @Published var isSaveEnabled: Bool = false

    @MainActor
    func onSaveTapped() {}

    init(accessToken: String = "") {
      self.accessToken = accessToken
    }
  }
}

#Preview("default") {
  HardcoverSettingsView(viewModel: HardcoverSettingsView.Model())
}
