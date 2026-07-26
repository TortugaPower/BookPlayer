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

  /// Whether the Quick Connect sheet is presented. Derived from the view model's
  /// `quickConnectStatus`: non-nil means there is something to render (poll progress, code,
  /// success transition, or terminal failure).
  private var isQuickConnectSheetPresented: Binding<Bool> {
    Binding(
      get: { viewModel.quickConnectStatus != nil },
      set: { newValue in
        // The user dismissed the sheet by gesture — clean up the in-flight flow.
        if !newValue { viewModel.handleCancelQuickConnect() }
      }
    )
  }

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
        // Alternative sign-in methods go ABOVE the username/password section.
        // `IntegrationServerFoundView` auto-focuses the username field, so this step always arrives
        // with the keyboard up; below Login these rows start out hidden behind it on smaller devices —
        // poor discoverability for what are meant to be peer paths to password sign-in, not footnotes.
        // At most one of these renders: AudiobookShelf opts into OIDC, Jellyfin into Quick Connect,
        // and each leaves the other at its protocol default of `false`.
        if viewModel.oidcSupported {
          IntegrationOIDCSectionView(
            buttonText: viewModel.oidcButtonText,
            isBusy: isLoading,
            onStart: onStartOIDC
          )
        } else if viewModel.oidcBlockedByInsecureTransport {
          // The server does offer SSO — say why we won't, rather than silently omitting it.
          IntegrationOIDCUnavailableSectionView()
        }
        if viewModel.quickConnectSupported {
          IntegrationQuickConnectSectionView(onStart: onStartQuickConnect)
        }
        IntegrationServerFoundView(
          username: $viewModel.form.username,
          password: $viewModel.form.password,
          // Don't raise the keyboard when an alternative sign-in is on offer — it would cover the
          // option above and presume the user came here to type a password.
          autoFocusesUsername: !viewModel.oidcSupported && !viewModel.quickConnectSupported,
          onCommit: onSignIn
        )
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
    .sheet(isPresented: isQuickConnectSheetPresented) {
      // Bound to the view model's status: a successful flow nils the status and the sheet
      // auto-dismisses; a failure keeps it up showing the error until the user taps OK.
      IntegrationQuickConnectSheetView(
        status: viewModel.quickConnectStatus ?? .retrievingCode,
        serverUrl: viewModel.form.serverUrl,
        onCancel: { viewModel.handleCancelQuickConnect() }
      )
      .environmentObject(theme)
    }
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
            // Tear down any in-flight Quick Connect before leaving: its poller lives on the view model,
            // not in `actionTask`, so it would otherwise keep running — and could persist a connection
            // after the user explicitly backed out. No-op when no flow is running.
            viewModel.handleCancelQuickConnect()
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
      // Safe to tear the Quick Connect flow down here: presenting a `.sheet` does NOT deliver
      // `onDisappear` to the presenter — it stays in the hierarchy — so this cannot fire when the Quick
      // Connect sheet opens. (`.fullScreenCover` and a navigation push do remove the presenter; this is
      // a `.sheet`.) Insurance for the case where the whole modal stack is torn down from elsewhere:
      // this view model is a `@StateObject` on the presenting sheet, so it would deallocate, dropping
      // the state subscription while the SDK controller — which self-retains via `mainTask` and has no
      // `deinit` — kept polling for its full ~16-minute budget. No-op when no flow is running.
      viewModel.handleCancelQuickConnect()
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
      } catch let error as URLError where error.code == .cancelled {
        // Same abort, different spelling. A cancelled `URLSession` task surfaces as
        // `URLError(.cancelled)`, not `CancellationError` — Get's data loader cancels the underlying
        // task rather than throwing — so without this arm cancelling one attempt pops an alert reading
        // "cancelled" over the attempt that replaced it.
        return
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
      } catch let error as URLError where error.code == .cancelled {
        // Same abort, different spelling. A cancelled `URLSession` task surfaces as
        // `URLError(.cancelled)`, not `CancellationError` — Get's data loader cancels the underlying
        // task rather than throwing — so without this arm cancelling one attempt pops an alert reading
        // "cancelled" over the attempt that replaced it.
        return
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
      } catch let error as URLError where error.code == .cancelled {
        // Same abort, different spelling. A cancelled `URLSession` task surfaces as
        // `URLError(.cancelled)`, not `CancellationError` — Get's data loader cancels the underlying
        // task rather than throwing — so without this arm cancelling one attempt pops an alert reading
        // "cancelled" over the attempt that replaced it.
        return
      } catch is CancellationError {
        return
      } catch {
        self.error = error
      }
    }
  }

  /// Starts the Quick Connect flow. Failures during the flow surface inside the sheet via the
  /// view model's `quickConnectStatus`; this handler only catches the synchronous setup error.
  /// No loading overlay — the sheet provides its own progress UI.
  func onStartQuickConnect() {
    // Routed through `actionTask` like every sibling handler — the property's own doc comment already
    // names Quick-Connect-start as one of the flows it tracks.
    actionTask?.cancel()
    actionTask = Task { @MainActor in
      do {
        try await viewModel.handleStartQuickConnect()
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

/// In-form section offering native SSO sign-in as an alternative to username/password. Shown in the
/// `.enteringCredentials` state when the validated server reported it supports OIDC.
private struct IntegrationOIDCSectionView: View {
  /// The provider label the server supplied, when there is one — the same wording the user sees in
  /// the server's own web login.
  var buttonText: String?
  /// Disables the row while a handshake is in flight. Without this the row stays live during the
  /// multi-second token exchange, and a second tap cancels the first attempt's task — surfacing an
  /// error alert on top of the flow the user just started.
  var isBusy: Bool
  /// Tapped to begin the flow. The caller drives `viewModel.handleStartOIDC()` so loading-state
  /// plumbing stays in the host view.
  var onStart: () -> Void

  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    ThemedSection {
      Button(action: onStart) {
        Label(
          buttonText ?? "integration_sso_button".localized,
          systemImage: "key.icloud"
        )
        .foregroundStyle(theme.linkColor)
      }
      .accessibilityHint(Text("integration_sso_button_hint".localized))
      .disabledWithOpacity(isBusy)
    } header: {
      // No explicit font: every sibling section header on this screen inherits the Form's default,
      // and setting one here made this header visibly smaller than "Server" / "Login".
      Text("integration_sso_section_header".localized)
        .foregroundStyle(theme.secondaryColor)
    } footer: {
      Text("integration_sso_section_footer".localized)
        .foregroundStyle(theme.secondaryColor)
    }
  }
}

/// Shown when the server advertises SSO but the connection is plaintext. Explaining the absence beats
/// silently hiding an option the user may have come here expecting.
private struct IntegrationOIDCUnavailableSectionView: View {
  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    ThemedSection {
      EmptyView()
    } header: {
      Text("integration_sso_section_header".localized)
        .foregroundStyle(theme.secondaryColor)
    } footer: {
      Text("integration_sso_requires_https".localized)
        .foregroundStyle(theme.secondaryColor)
    }
  }
}
