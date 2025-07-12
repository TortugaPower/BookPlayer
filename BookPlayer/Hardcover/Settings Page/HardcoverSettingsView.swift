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
  @State var isValid = true

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
          .onChange(of: viewModel.accessToken) { new in
            isValid = new.isEmpty || !new.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          }
        } header: {
          Text("hardcover_api_access_title".localized)
            .foregroundColor(themeViewModel.secondaryColor)
        } footer: {
          if let attributedString = try? AttributedString(markdown: "hardcover_api_access_footer".localized) {
            Text(attributedString)
              .foregroundColor(themeViewModel.secondaryColor)
          }
        }

        Section {
          Toggle("hardcover_auto_match_books".localized, isOn: $viewModel.autoMatch)
            .foregroundColor(themeViewModel.primaryColor)

          Toggle("hardcover_auto_add_want_to_read".localized, isOn: $viewModel.autoAddWantToRead)
            .foregroundColor(themeViewModel.primaryColor)
        } header: {
          Text("hardcover_automation_title".localized)
            .foregroundColor(themeViewModel.secondaryColor)
        } footer: {
          Text("hardcover_automation_description".localized)
            .foregroundColor(themeViewModel.secondaryColor)
        }

        Section {
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Text("hardcover_reading_threshold".localized)
                .foregroundColor(themeViewModel.primaryColor)
              Spacer()
              Text("\(Int(viewModel.readingThreshold))%")
                .foregroundColor(themeViewModel.secondaryColor)
            }

            Slider(
              value: $viewModel.readingThreshold,
              in: 1...99,
              step: 1.0
            )
            .accentColor(themeViewModel.linkColor)
            .accessibilityLabel("hardcover_reading_threshold".localized)
            .accessibilityValue("\(Int(viewModel.readingThreshold)) percent")
          }
        } header: {
          Text("hardcover_progress_tracking_title".localized)
            .foregroundColor(themeViewModel.secondaryColor)
        } footer: {
          Text("hardcover_progress_tracking_footer".localized)
            .foregroundColor(themeViewModel.secondaryColor)
        }
        .navigationBarTitleDisplayMode(.inline)

        if viewModel.showUnlinkButton {
          Section {
            Button("hardcover_unlink_button".localized, role: .destructive) {
              viewModel.onUnlinkTapped()
              dismiss()
            }
            .frame(maxWidth: .infinity)
          }
        }
      }
      .toolbar {
        navigationBar
      }
    }
    .tint(themeViewModel.linkColor)
    .environmentObject(themeViewModel)
  }

  @ToolbarContentBuilder
  var navigationBar: some ToolbarContent {
    ToolbarItem(placement: .principal) {
      Text("hardcover_settings_title".localized)
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
        }
      )
      .accessibilityLabel("voiceover_close_button".localized)
    }
    ToolbarItemGroup(placement: .confirmationAction) {
      Button(
        "save_button".localized,
        action: {
          viewModel.onSaveTapped()
          dismiss()
        }
      )
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
}
