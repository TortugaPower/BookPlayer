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

        Section {
          Toggle("Auto-match books", isOn: $viewModel.autoMatch)
            .foregroundColor(themeViewModel.primaryColor)
          
          Toggle("Auto-add to Want to Read", isOn: $viewModel.autoAddWantToRead)
            .foregroundColor(themeViewModel.primaryColor)
        } header: {
          Text("Automation".localized)
            .foregroundColor(themeViewModel.secondaryColor)
        } footer: {
          Text(
            """
            Auto-match will automatically find and link books from Hardcover when books are added to your library. It intelligently handles bulk imports by matching unique books while skipping items that would conflict with each other.
              
            Auto-add will automatically add books to your Hardcover **Want to Read** list when they are added to BookPlayer or when a Hardcover book is assigned.
            """
          )
          .foregroundColor(themeViewModel.secondaryColor)
        }

        Section {
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Text("Reading threshold")
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
          }
        } header: {
          Text("Progress Tracking".localized)
            .foregroundColor(themeViewModel.secondaryColor)
        } footer: {
          Text("Sets the minimum progress percentage required before a book is marked as **Currently Reading** in your Hardcover library.")
            .foregroundColor(themeViewModel.secondaryColor)
        }
        .navigationBarTitleDisplayMode(.inline)
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
          dismiss()
        }
      )
    }
  }
}

extension HardcoverSettingsView {
  class Model: ObservableObject {
    @Published var accessToken: String
    @Published var autoMatch: Bool
    @Published var autoAddWantToRead: Bool
    @Published var readingThreshold: Double

    @MainActor
    func onSaveTapped() {}

    init(
      accessToken: String = "",
      autoMatch: Bool = false,
      autoAddWantToRead: Bool = false,
      readingThreshold: Double = 1.0
    ) {
      self.accessToken = accessToken
      self.autoMatch = autoMatch
      self.autoAddWantToRead = autoAddWantToRead
      self.readingThreshold = readingThreshold
    }
  }
}

#Preview("default") {
  HardcoverSettingsView(viewModel: HardcoverSettingsView.Model())
}
