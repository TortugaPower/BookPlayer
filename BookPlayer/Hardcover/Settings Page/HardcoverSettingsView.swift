//
//  HardcoverSettingsView.swift
//  BookPlayer
//
//  Created by Jeremy Grenier on 6/27/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import AuthenticationServices
import BookPlayerKit
import SwiftUI

struct HardcoverSettingsView: View {
  @Environment(\.dismiss) var dismiss
  @Environment(\.webAuthenticationSession) private var webAuthenticationSession
  @EnvironmentObject var theme: ThemeViewModel

  @StateObject var viewModel: HardcoverSettingsView.Model
  @State var isValid = true

  @FocusState private var isTextFieldFocused: Bool

  var body: some View {
    Form {
      if viewModel.isSignedInWithOAuth {
        ThemedSection {
          Text(connectedTitle)
            .foregroundStyle(theme.primaryColor)

          if viewModel.needsSignInAgain {
            Button {
              signIn()
            } label: {
              HStack {
                Text("hardcover_sign_in_again_button".localized)
                Spacer()
                if viewModel.isSigningIn {
                  ProgressView()
                    .controlSize(.small)
                }
              }
            }
            .foregroundStyle(theme.linkColor)
            .disabled(viewModel.isSigningIn)
          }
        } header: {
          Text("hardcover_account_title".localized)
            .foregroundStyle(theme.secondaryColor)
        } footer: {
          if viewModel.needsSignInAgain {
            Text("hardcover_sign_in_again_footer".localized)
              .foregroundStyle(theme.secondaryColor)
          }
        }
      } else {
        if viewModel.canSignIn {
          signInSection
        }

        apiKeySection
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
        /// Its "Currently Reading" is Markdown bold, which `Text` only reads in a literal
        if let attributedString = try? AttributedString(markdown: "hardcover_progress_tracking_footer".localized) {
          Text(attributedString)
            .foregroundStyle(theme.secondaryColor)
        }
      }
      .navigationBarTitleDisplayMode(.inline)

      if viewModel.isConnected {
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
    .alert("hardcover_sign_in_failed_title".localized, isPresented: $viewModel.signInFailed) {
      Button("ok_button".localized, role: .cancel) {}
    } message: {
      Text("hardcover_sign_in_failed_message".localized)
    }
  }

  var connectedTitle: String {
    guard let username = viewModel.connectedUsername else {
      return "hardcover_connected".localized
    }

    return String(format: "hardcover_connected_as".localized, username)
  }

  var signInSection: some View {
    ThemedSection {
      Button {
        signIn()
      } label: {
        /// Both labels are always laid out, one hidden, so switching doesn't resize the button;
        /// the small spinner is shorter than a line of text
        ZStack {
          Text("hardcover_sign_in_button".localized)
            .opacity(viewModel.isSigningIn ? 0 : 1)
            .accessibilityHidden(viewModel.isSigningIn)

          HStack(spacing: 8) {
            ProgressView()
              .controlSize(.small)
              .tint(.white)
            Text("hardcover_signing_in".localized)
          }
          .opacity(viewModel.isSigningIn ? 1 : 0)
          .accessibilityHidden(!viewModel.isSigningIn)
        }
        .bpFont(.headline)
        .frame(maxWidth: .infinity)
      }
      .buttonStyle(.glassProminent)
      .controlSize(.large)
      .tint(theme.linkColor)
      .disabled(viewModel.isSigningIn)
      .listRowBackground(Color.clear)
      .listRowInsets(EdgeInsets())
    } header: {
      Text("hardcover_account_title".localized)
        .foregroundStyle(theme.secondaryColor)
    } footer: {
      Text("hardcover_sign_in_footer".localized)
        .foregroundStyle(theme.secondaryColor)
    }
  }

  var apiKeySection: some View {
    ThemedSection {
      TextField(
        "hc_pat_…",
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
        isValid = new.isEmpty || !HardcoverService.apiKey(from: new).isEmpty
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
  }

  /// Hardcover's authorize page in the shared browser session, so a signed-in browser isn't asked to sign in again
  func signIn() {
    let webAuthenticationSession = webAuthenticationSession

    Task {
      await viewModel.onSignInTapped { url in
        try await webAuthenticationSession.authenticate(
          using: url,
          callback: .customScheme(HardcoverOAuth.callbackScheme),
          preferredBrowserSession: .shared,
          additionalHeaderFields: [:]
        )
      }
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

    @Published var isConnected: Bool
    @Published var isSignedInWithOAuth: Bool
    @Published var connectedUsername: String?
    @Published var needsSignInAgain: Bool
    @Published var isSigningIn = false
    @Published var signInFailed = false

    /// Signing in needs BookPlayer's registered Hardcover app; without it only API keys work
    let canSignIn: Bool

    @MainActor
    func onSaveTapped() {}

    @MainActor
    func onUnlinkTapped() {}

    /// - Parameter authenticate: opens Hardcover's authorize page and returns the redirect
    @MainActor
    func onSignInTapped(authenticate: @escaping (URL) async throws -> URL) async {}

    init(
      accessToken: String = "",
      autoMatch: Bool = false,
      autoAddWantToRead: Bool = false,
      readingThreshold: Double = 1.0,
      isConnected: Bool = false,
      isSignedInWithOAuth: Bool = false,
      connectedUsername: String? = nil,
      needsSignInAgain: Bool = false,
      canSignIn: Bool = true
    ) {
      self.needsSignInAgain = needsSignInAgain
      self.accessToken = accessToken
      self.autoMatch = autoMatch
      self.autoAddWantToRead = autoAddWantToRead
      self.readingThreshold = readingThreshold
      self.isConnected = isConnected
      self.isSignedInWithOAuth = isSignedInWithOAuth
      self.connectedUsername = connectedUsername
      self.canSignIn = canSignIn
    }
  }
}

#Preview("default") {
  HardcoverSettingsView(viewModel: HardcoverSettingsView.Model())
    .environmentObject(ThemeViewModel())
}

#Preview("signed in") {
  HardcoverSettingsView(
    viewModel: HardcoverSettingsView.Model(
      isConnected: true,
      isSignedInWithOAuth: true,
      connectedUsername: "reader"
    )
  )
  .environmentObject(ThemeViewModel())
}
