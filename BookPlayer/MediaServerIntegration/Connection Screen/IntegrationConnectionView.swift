//
//  IntegrationConnectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/5/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct IntegrationConnectionView<VM: IntegrationConnectionViewModelProtocol>: View {
  @ObservedObject var viewModel: VM

  let integrationName: String

  @State private var isLoading = false
  @State private var error: Error?

  /// Tracks the in-flight network task for connect/sign-in/Quick-Connect-start so the view
  /// can cancel it on dismissal. Without this, swiping the sheet down while a sign-in is
  /// still in flight would let the view model persist a connection the user thought they
  /// gave up on.
  @State private var actionTask: Task<Void, Never>?

  @EnvironmentObject var theme: ThemeViewModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    Form {
      switch viewModel.signInFlow {
      case .enteringServerURL:
        IntegrationDisconnectedView(
          serverUrl: $viewModel.form.serverUrl,
          placeholderURL: integrationName == "Jellyfin"
            ? "http://jellyfin.example.com:8096"
            : "http://audiobookshelf.example.com",
          integrationName: integrationName,
          onCommit: onConnect
        )
        IntegrationCustomHeadersSectionView(
          customHeaders: $viewModel.form.customHeaders
        )
      case .enteringCredentials:
        IntegrationServerInformationSectionView(
          serverName: viewModel.form.serverName,
          serverUrl: viewModel.form.serverUrl
        )
        IntegrationServerFoundView(
          username: $viewModel.form.username,
          password: $viewModel.form.password,
          onCommit: onSignIn
        )
        if viewModel.oidcSupported {
          IntegrationOIDCSectionView(onStart: onStartOIDC)
        }
        IntegrationCustomHeadersSectionView(
          customHeaders: $viewModel.form.customHeaders
        )
      case .none:
        // Not in sign-in flow → render the connection-details UI (server info, custom
        // headers, logout) for the active connection. Multi-server management is in
        // `MediaServersView`, not here.
        IntegrationServerInformationSectionView(
          serverName: viewModel.form.serverName,
          serverUrl: viewModel.form.serverUrl
        )
        IntegrationCustomHeadersSectionView(
          customHeaders: $viewModel.form.customHeaders,
          onCommit: { viewModel.handleCustomHeadersUpdate() }
        )
        IntegrationConnectedView(viewModel: viewModel)
      }
    }
    .scrollContentBackground(.hidden)
    .background(theme.systemBackgroundColor)
    .errorAlert(error: $error)
    .overlay {
      Group {
        if isLoading {
          ProgressView()
            .tint(.white)
            .padding()
            .background(
              Color.black
                .opacity(0.9)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            )
            .ignoresSafeArea(.all)
        }
      }
    }
    .toolbar {
      // Shown in every state, including Add Server. Without it that flow renders a
      // bare Cancel/Connect bar, and since both integrations share this screen there
      // is nothing on it telling you whether you're adding a Jellyfin or an
      // AudiobookShelf server — entering one server's URL into the other's flow just
      // fails with an opaque 404 from the wrong probe endpoint.
      ToolbarItem(placement: .principal) {
        Text(localizedNavigationTitle)
          .bpFont(.headline)
          .foregroundStyle(theme.primaryColor)
          .accessibilityAddTraits(.isHeader)
      }
      if viewModel.isAddingServer {
        ToolbarItem(placement: .cancellationAction) {
          Button("cancel_button".localized) {
            viewModel.handleCancelAddServerAction()
            dismiss()
          }
          .foregroundStyle(theme.linkColor)
        }
        ToolbarItemGroup(placement: .confirmationAction) {
          switch viewModel.signInFlow {
          case .enteringCredentials: signInToolbarButton
          case .enteringServerURL, .none: connectToolbarButton
          }
        }
      } else {
        ToolbarItemGroup(placement: .confirmationAction) {
          switch viewModel.signInFlow {
          case .enteringServerURL: connectToolbarButton
          case .enteringCredentials: signInToolbarButton
          case .none: EmptyView()
          }
        }
      }
    }
    .tint(theme.linkColor)
    .onDisappear {
      actionTask?.cancel()
      actionTask = nil
    }
  }

  // MARK: Utils

  func onConnect() {
    actionTask?.cancel()
    isLoading = true
    actionTask = Task { @MainActor in
      defer { isLoading = false }
      do {
        try await viewModel.handleConnectAction()
        try Task.checkCancellation()
      } catch is CancellationError {
        // Sheet dismissed mid-flight; nothing to surface.
      } catch {
        self.error = error
      }
    }
  }

  func onSignIn() {
    actionTask?.cancel()
    isLoading = true
    actionTask = Task { @MainActor in
      defer { isLoading = false }
      do {
        try await viewModel.handleSignInAction()
        try Task.checkCancellation()
      } catch is CancellationError {
        return
      } catch {
        self.error = error
      }
    }
  }

  /// Starts the native SSO flow. The system web-auth sheet drives the IdP handshake; the
  /// loading overlay covers the subsequent token exchange. User cancellation is swallowed.
  func onStartOIDC() {
    actionTask?.cancel()
    isLoading = true
    actionTask = Task { @MainActor in
      defer { isLoading = false }
      do {
        try await viewModel.handleStartOIDC()
        try Task.checkCancellation()
      } catch is CancellationError {
        return
      } catch {
        self.error = error
      }
    }
  }

  // MARK: - Navigation Title

  private var localizedNavigationTitle: String {
    viewModel.signInFlow == nil
      ? "integration_connection_details_title".localized
      : integrationName
  }

  // MARK: - Navigation Buttons

  @ViewBuilder
  private var connectToolbarButton: some View {
    Button(
      "integration_connect_button",
      action: onConnect
    )
    .foregroundStyle(theme.linkColor)
    .disabledWithOpacity(viewModel.form.serverUrl.isEmpty)
  }

  @ViewBuilder
  private var signInToolbarButton: some View {
    Button(
      "integration_sign_in_button",
      action: onSignIn
    )
    .foregroundStyle(theme.linkColor)
    .disabledWithOpacity(
      viewModel.form.serverUrl.isEmpty || viewModel.form.username.isEmpty
    )
  }
}

/// In-form section offering native SSO sign-in as an alternative to username/password. Shown
/// in the `.enteringCredentials` state for integrations whose view model sets `oidcSupported`
/// (AudiobookShelf).
private struct IntegrationOIDCSectionView: View {
  /// Tapped to begin the flow. The caller drives `viewModel.handleStartOIDC()` so loading-state
  /// plumbing stays in the host view.
  var onStart: () -> Void

  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    ThemedSection {
      Button(action: onStart) {
        Label(
          "integration_sso_button".localized,
          systemImage: "lock.shield"
        )
        .foregroundStyle(theme.linkColor)
      }
      .accessibilityHint(Text("integration_sso_button_hint".localized))
    } header: {
      Text("integration_sso_section_header".localized)
        .foregroundStyle(theme.secondaryColor)
    } footer: {
      Text("integration_sso_section_footer".localized)
        .foregroundStyle(theme.secondaryColor)
    }
  }
}
