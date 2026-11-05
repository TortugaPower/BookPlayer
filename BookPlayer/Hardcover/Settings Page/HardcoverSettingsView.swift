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

/// Signing in comes first: until the user signs in, the page offers only that. An API key saved by
/// an earlier version keeps syncing, but isn't shown here; signing in replaces it. Once signed in, the
/// settings apply as they change, like the rest of Settings: there's nothing to save
struct HardcoverSettingsView: View {
  @Environment(\.webAuthenticationSession) private var webAuthenticationSession
  @EnvironmentObject var theme: ThemeViewModel

  @StateObject var viewModel: HardcoverSettingsView.Model

  /// Read by `HardcoverService` from the same suite; AppDelegate registers their defaults there
  @AppStorage(Constants.UserDefaults.hardcoverAutoMatch, store: UserDefaults.sharedDefaults)
  private var autoMatch = false
  @AppStorage(Constants.UserDefaults.hardcoverAutoAddWantToRead, store: UserDefaults.sharedDefaults)
  private var autoAddWantToRead = true
  @AppStorage(Constants.UserDefaults.hardcoverReadingThreshold, store: UserDefaults.sharedDefaults)
  private var readingThreshold = 1.0

  var body: some View {
    Form {
      if viewModel.isSignedIn {
        accountSection
        automationSection
        progressTrackingSection
        logOutSection
      } else {
        signInSection
      }
    }
    .scrollContentBackground(.hidden)
    .background(theme.systemBackgroundColor)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .principal) {
        Text("hardcover_settings_title".localized)
          .bpFont(.headline)
          .foregroundStyle(theme.primaryColor)
      }
    }
    .alert("error_title".localized, isPresented: $viewModel.signInFailed) {
      Button("ok_button".localized, role: .cancel) {}
    } message: {
      Text("hardcover_sign_in_failed_message".localized)
    }
  }

  /// The Hardcover username, read from `me` when signing in
  var accountSection: some View {
    ThemedSection {
      if let username = viewModel.connectedUsername {
        Text(username)
          .foregroundStyle(theme.primaryColor)
      }
    } header: {
      Text("account_title".localized)
        .foregroundStyle(theme.secondaryColor)
    }
  }

  var automationSection: some View {
    ThemedSection {
      Toggle("hardcover_auto_match_books".localized, isOn: $autoMatch)
        .foregroundStyle(theme.primaryColor)

      Toggle("hardcover_auto_add_want_to_read".localized, isOn: $autoAddWantToRead)
        .foregroundStyle(theme.primaryColor)
    } header: {
      Text("hardcover_automation_title".localized)
        .foregroundStyle(theme.secondaryColor)
    } footer: {
      Text("hardcover_automation_description".localized)
        .foregroundStyle(theme.secondaryColor)
    }
  }

  var progressTrackingSection: some View {
    ThemedSection {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("hardcover_reading_threshold".localized)
            .foregroundStyle(theme.primaryColor)
          Spacer()
          Text("\(Int(readingThreshold))%")
            .foregroundStyle(theme.secondaryColor)
        }

        Slider(
          value: $readingThreshold,
          in: 1...99,
          step: 1.0
        )
        .accentColor(theme.linkColor)
        .accessibilityLabel("hardcover_reading_threshold".localized)
        .accessibilityValue("\(Int(readingThreshold)) percent")
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
  }

  /// The page stays, showing Sign In, so another account can be signed in right away
  var logOutSection: some View {
    ThemedSection {
      Button("logout_title".localized, role: .destructive) {
        viewModel.onLogOutTapped()
      }
      .frame(maxWidth: .infinity)
      .foregroundStyle(.red)
    }
  }

  var signInSection: some View {
    ThemedSection {
      Button {
        signIn()
      } label: {
        /// Both are always laid out, one hidden, so switching doesn't resize the button; the small
        /// spinner is shorter than a line of text
        ZStack {
          Text("integration_sign_in_button".localized)
            .opacity(viewModel.isSigningIn ? 0 : 1)
            .accessibilityHidden(viewModel.isSigningIn)

          ProgressView()
            .controlSize(.small)
            .tint(.white)
            .opacity(viewModel.isSigningIn ? 1 : 0)
            .accessibilityHidden(!viewModel.isSigningIn)
        }
        .bpFont(.headline)
        /// Settings sets the theme's primary color on everything below it, which would otherwise
        /// win over the prominent style's label color and put dark text on the tint
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
      }
      .buttonStyle(.glassProminent)
      .controlSize(.large)
      .tint(theme.linkColor)
      .disabled(viewModel.isSigningIn)
      .listRowBackground(Color.clear)
      .listRowInsets(EdgeInsets())
    } header: {
      Text("account_title".localized)
        .foregroundStyle(theme.secondaryColor)
    }
  }

  /// Hardcover's authorize page in a private browser session, without Safari's cookies: Hardcover's
  /// login form always shows, so after logging out the user can sign in to another account
  func signIn() {
    let webAuthenticationSession = webAuthenticationSession

    Task {
      await viewModel.onSignInTapped { url in
        try await webAuthenticationSession.authenticate(
          using: url,
          callback: .customScheme(HardcoverOAuth.callbackScheme),
          preferredBrowserSession: .ephemeral,
          additionalHeaderFields: [:]
        )
      }
    }
  }
}

extension HardcoverSettingsView {
  class Model: ObservableObject {
    /// Signed in with Hardcover (OAuth). An API key from an earlier version doesn't count here
    @Published var isSignedIn: Bool
    @Published var connectedUsername: String?
    @Published var isSigningIn = false
    @Published var signInFailed = false

    @MainActor
    func onLogOutTapped() {}

    /// - Parameter authenticate: opens Hardcover's authorize page and returns the redirect
    @MainActor
    func onSignInTapped(authenticate: @escaping (URL) async throws -> URL) async {}

    init(
      isSignedIn: Bool = false,
      connectedUsername: String? = nil
    ) {
      self.isSignedIn = isSignedIn
      self.connectedUsername = connectedUsername
    }
  }
}

#Preview("signed out") {
  HardcoverSettingsView(viewModel: HardcoverSettingsView.Model())
    .environmentObject(ThemeViewModel())
}

#Preview("signed in") {
  HardcoverSettingsView(
    viewModel: HardcoverSettingsView.Model(
      isSignedIn: true,
      connectedUsername: "reader"
    )
  )
  .environmentObject(ThemeViewModel())
}
