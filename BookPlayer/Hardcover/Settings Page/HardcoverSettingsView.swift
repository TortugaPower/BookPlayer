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
  @EnvironmentObject var theme: ThemeViewModel

  @StateObject var viewModel: HardcoverSettingsView.Model
  @State var isValid = true

  @FocusState private var isTextFieldFocused: Bool

  var body: some View {
    Form {
      ThemedSection {
        TextField(
          "Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXV…",
          text: $viewModel.accessToken
        )
        .foregroundStyle(theme.primaryColor)
        .autocapitalization(.none)
        .autocorrectionDisabled()
        .focused($isTextFieldFocused)
        .submitLabel(.done)
        .onSubmit {
          isTextFieldFocused = false
        }
        .onChange(of: viewModel.accessToken) { _, new in
          isValid = new.isEmpty || !new.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
      } header: {
        Text("hardcover_api_access_title".localized)
          .foregroundStyle(theme.secondaryColor)
      } footer: {
        if let attributedString = try? AttributedString(markdown: "hardcover_api_access_footer".localized) {
          Text(attributedString)
            .foregroundStyle(theme.secondaryColor)
        }
      }

      ThemedSection {
        Toggle("hardcover_auto_match_books".localized, isOn: $viewModel.autoMatch)
          .foregroundStyle(theme.primaryColor)

        Toggle("hardcover_auto_add_want_to_read".localized, isOn: $viewModel.autoAddWantToRead)
          .foregroundStyle(theme.primaryColor)
      } header: {
        Text("hardcover_automation_title".localized)
          .foregroundStyle(theme.secondaryColor)
      } footer: {
        Text("hardcover_automation_description".localized)
          .foregroundStyle(theme.secondaryColor)
      }

      ThemedSection {
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text("hardcover_reading_threshold".localized)
              .foregroundStyle(theme.primaryColor)
            Spacer()
            Text("\(Int(viewModel.readingThreshold))%")
              .foregroundStyle(theme.secondaryColor)
          }

          Slider(
            value: $viewModel.readingThreshold,
            in: 1...99,
            step: 1.0
          )
          .accentColor(theme.linkColor)
          .accessibilityLabel("hardcover_reading_threshold".localized)
          .accessibilityValue("\(Int(viewModel.readingThreshold)) percent")
        }
      } header: {
        Text("hardcover_progress_tracking_title".localized)
          .foregroundStyle(theme.secondaryColor)
      } footer: {
        Text("hardcover_progress_tracking_footer".localized)
          .foregroundStyle(theme.secondaryColor)
      }
      .navigationBarTitleDisplayMode(.inline)

      if viewModel.showUnlinkButton {
        ThemedSection {
          Button("hardcover_unlink_button".localized, role: .destructive) {
            viewModel.onUnlinkTapped()
            dismiss()
          }
          .frame(maxWidth: .infinity)
          .foregroundStyle(.red)
        }
      }
    }
    .scrollContentBackground(.hidden)
    .background(theme.systemBackgroundColor)
    .toolbar {
      navigationBar
    }
  }

  @ToolbarContentBuilder
  var navigationBar: some ToolbarContent {
    ToolbarItem(placement: .principal) {
      Text("hardcover_settings_title".localized)
        .bpFont(.headline)
        .foregroundStyle(theme.primaryColor)
    }
    ToolbarItemGroup(placement: .confirmationAction) {
      Button(
        "save_button".localized,
        action: {
          viewModel.onSaveTapped()
          dismiss()
        }
      )
      .foregroundStyle(theme.linkColor)
      .disabled(!isValid)
    }
  }
}

extension HardcoverSettingsView {
  class Model: ObservableObject {
    @Published var accessToken: String
    @Published var autoMatch: Bool
    @Published var autoAddWantToRead: Bool
    @Published var readingThreshold: Double

    let showUnlinkButton: Bool

    @MainActor
    func onSaveTapped() {}

    @MainActor
    func onUnlinkTapped() {}

    init(
      accessToken: String = "",
      autoMatch: Bool = false,
      autoAddWantToRead: Bool = false,
      readingThreshold: Double = 1.0,
      showUnlinkButton: Bool = false
    ) {
      self.accessToken = accessToken
      self.autoMatch = autoMatch
      self.autoAddWantToRead = autoAddWantToRead
      self.readingThreshold = readingThreshold
      self.showUnlinkButton = showUnlinkButton
    }
  }
}

#Preview("default") {
  HardcoverSettingsView(viewModel: HardcoverSettingsView.Model())
    .environmentObject(ThemeViewModel())
}
