//
//  IntegrationConnectionFlowView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 8/8/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

/// The redesigned add-server flow: one pushed screen per decision.
///
/// Address (root) → method chooser (only when the server offers an alternative to the password) →
/// password form. Quick Connect and SSO present modally from wherever they're started — they hand off
/// to an external authority and come back, which is what a modal says and a push doesn't.
///
/// Owns its `NavigationStack`, with the path living on the view model — the routing decision (what
/// Connect lands on) is view-model logic under test, and success/cancel clear the path there so no
/// pushed screen can outlive the flow. Presenters therefore must NOT wrap this in another stack.
struct IntegrationConnectionFlowView<VM: IntegrationConnectionViewModelProtocol>: View {
  @ObservedObject var viewModel: VM

  /// Which integration this flow signs into. Placeholders and defaults key off this, not off the
  /// display string — a renamed `integrationName` must never silently flip them.
  let kind: IntegrationKind

  let integrationName: String

  @State private var isLoading = false
  @State private var error: Error?

  /// In-flight connect/sign-in/alternative task, cancelled when the flow disappears so dismissing
  /// the sheet can't let a stale attempt persist a connection the user gave up on.
  @State private var actionTask: Task<Void, Never>?

  @EnvironmentObject var theme: ThemeViewModel
  @Environment(\.dismiss) private var dismiss

  private var isQuickConnectSheetPresented: Binding<Bool> {
    Binding(
      get: { viewModel.quickConnectStatus != nil },
      set: { if !$0 { viewModel.handleCancelAlternativeSignIn() } }
    )
  }

  var body: some View {
    NavigationStack(path: $viewModel.flowPath) {
      IntegrationAddressScreen(
        viewModel: viewModel,
        kind: kind,
        integrationName: integrationName,
        isLoading: isLoading,
        onConnect: onConnect
      )
      .navigationDestination(for: ConnectionFlowStep.self) { step in
        switch step {
        case .method:
          IntegrationMethodScreen(
            viewModel: viewModel,
            isLoading: isLoading,
            onStartAlternative: onStartAlternativeSignIn
          )
        case .password:
          IntegrationPasswordScreen(
            viewModel: viewModel,
            isLoading: isLoading,
            onSignIn: onSignIn
          )
        case .headersDetail:
          IntegrationHeadersDetailScreen(headers: viewModel.form.customHeaders)
        }
      }
    }
    .tint(theme.linkColor)
    .errorAlert(error: $error)
    .sheet(isPresented: isQuickConnectSheetPresented) {
      IntegrationQuickConnectSheetView(
        status: viewModel.quickConnectStatus ?? .retrievingCode,
        serverUrl: viewModel.form.serverUrl,
        onCancel: { viewModel.handleCancelAlternativeSignIn() }
      )
      .environmentObject(theme)
    }
    .overlay {
      if isLoading {
        ProgressView()
          .tint(.white)
          .padding()
          .background(Color.black.opacity(0.9).clipShape(RoundedRectangle(cornerRadius: 10)))
      }
    }
    .onDisappear {
      actionTask?.cancel()
      actionTask = nil
      viewModel.handleCancelAlternativeSignIn()
    }
  }

  // MARK: - Actions

  /// Runs `work` in the tracked task with the shared cancellation treatment: a cancelled attempt —
  /// whichever spelling it surfaces as — stays silent instead of popping an alert over its successor.
  private func run(showsOverlay: Bool, _ work: @escaping () async throws -> Void) {
    actionTask?.cancel()
    if showsOverlay { isLoading = true }
    actionTask = Task { @MainActor in
      defer { if showsOverlay { isLoading = false } }
      do {
        try await work()
        try Task.checkCancellation()
      } catch let error as URLError where error.code == .cancelled {
        return
      } catch is CancellationError {
        return
      } catch {
        self.error = error
      }
    }
  }

  private func onConnect() {
    run(showsOverlay: true) { try await viewModel.handleConnectAction() }
  }

  private func onSignIn() {
    run(showsOverlay: true) { try await viewModel.handleSignInAction() }
  }

  private func onStartAlternativeSignIn() {
    guard let method = viewModel.alternativeSignIn else { return }
    // OIDC's token exchange hides behind the system browser sheet, so the overlay covers it.
    // Quick Connect presents a sheet with its own progress UI — an overlay would stack spinners.
    let showsOverlay: Bool
    switch method {
    case .oidc: showsOverlay = true
    case .quickConnect: showsOverlay = false
    }
    run(showsOverlay: showsOverlay) { try await viewModel.handleStartAlternativeSignIn() }
  }
}

// MARK: - Screen 1 · Address

/// Server address as explicit fields — scheme, host (carrying any reverse-proxy subpath), port — plus
/// the custom headers, which are editable here and only here. Connect is pinned at the bottom, the
/// `LoginView` pattern, so the primary action sits in the same place on every screen of the flow.
struct IntegrationAddressScreen<VM: IntegrationConnectionViewModelProtocol>: View {
  @ObservedObject var viewModel: VM

  let kind: IntegrationKind
  let integrationName: String
  let isLoading: Bool
  var onConnect: () -> Void

  /// The fields, seeded from the form's URL so re-auth and edit-connection arrive prefilled. Written
  /// back as an assembled string only on Connect — the form stays the single source the services read.
  @State private var address: IntegrationServerAddress

  /// The port as typed. Kept as text so emptying the field is representable; parsed on change.
  @State private var portText: String

  @EnvironmentObject var theme: ThemeViewModel
  @Environment(\.dismiss) private var dismiss

  init(
    viewModel: VM,
    kind: IntegrationKind,
    integrationName: String,
    isLoading: Bool,
    onConnect: @escaping () -> Void
  ) {
    self.viewModel = viewModel
    self.kind = kind
    self.integrationName = integrationName
    self.isLoading = isLoading
    self.onConnect = onConnect
    let parsed = IntegrationServerAddress(parsing: viewModel.form.serverUrl)
      ?? IntegrationServerAddress(scheme: .https, host: "")
    self._address = State(initialValue: parsed)
    self._portText = State(initialValue: parsed.port.map(String.init) ?? "")
  }

  /// The usual port for this integration, shown as a placeholder example — never substituted.
  /// An empty field means no port, exactly as in a browser.
  private var usualPort: String {
    switch kind {
    case .jellyfin: return "8096"
    case .audiobookshelf: return "13378"
    }
  }

  private var hostPlaceholder: String {
    switch kind {
    case .jellyfin: return "jellyfin.example.com"
    case .audiobookshelf: return "audiobookshelf.example.com"
    }
  }

  var body: some View {
    ZStack(alignment: .bottom) {
      Form {
        ThemedSection {
          Picker("", selection: $address.scheme) {
            // Protocol identifiers, not words — deliberately unlocalized.
            ForEach(IntegrationServerAddress.Scheme.allCases, id: \.self) {
              Text($0.rawValue).tag($0)
            }
          }
          .pickerStyle(.segmented)
          .accessibilityLabel(Text("integration_address_scheme_label".localized))

          HStack {
            Text("integration_address_host_label".localized)
              .foregroundStyle(theme.primaryColor)
            ClearableTextField(
              hostPlaceholder,
              text: $address.hostField
            )
            .multilineTextAlignment(.trailing)
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            // The row's Text label isn't associated with the field — without this VoiceOver reads
            // the placeholder hostname as if it were the field's name.
            .accessibilityLabel(Text("integration_address_host_label".localized))
          }

          HStack {
            Text("integration_address_port_label".localized)
              .foregroundStyle(theme.primaryColor)
            TextField(usualPort, text: $portText)
              .multilineTextAlignment(.trailing)
              .keyboardType(.numberPad)
              // Same association gap — and here the placeholder is a bare number, so an unlabelled
              // field announces as "8096", which is meaningless.
              .accessibilityLabel(Text("integration_address_port_label".localized))
              .onChange(of: portText) { _, newValue in
                address.port = Int(newValue).flatMap { (1...65535).contains($0) ? $0 : nil }
              }
          }
        } header: {
          Text("integration_server_section_header".localized)
            .foregroundStyle(theme.secondaryColor)
        } footer: {
          // The assembled URL, so what Connect will actually dial is visible before tapping it —
          // the part that makes a split address field trustworthy.
          if let urlString = address.urlString {
            Text(verbatim: urlString)
              .foregroundStyle(theme.secondaryColor)
          }
        }

        IntegrationCustomHeadersSectionView(customHeaders: $viewModel.form.customHeaders)
      }
      .applyListStyle(with: theme, background: theme.systemBackgroundColor)
      .safeAreaInset(edge: .bottom) { Color.clear.frame(height: Self.footerClearance) }

      IntegrationFlowPrimaryButton(
        title: "integration_connect_button".localized,
        isDisabled: address.url == nil || isLoading
      ) {
        // A paste of a full URL into the host field carries the whole address; decompose it into
        // the fields rather than sending a host that contains a scheme.
        if let pasted = IntegrationServerAddress(parsing: address.hostField) {
          address = pasted
          portText = pasted.port.map(String.init) ?? ""
        }
        viewModel.form.serverUrl = address.urlString ?? ""
        onConnect()
      }
    }
    .navigationTitle(integrationName)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        // Add Server gets a worded Cancel that also tears down the in-flight VM state; the
        // initial-connect and re-auth presentations get the X the old sheet wrappers injected —
        // the flow owns its NavigationStack now, so the affordance has to live here.
        if viewModel.isAddingServer {
          Button("cancel_button".localized) {
            viewModel.handleCancelAddServerAction()
            dismiss()
          }
          .foregroundStyle(theme.linkColor)
        } else {
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark")
              .foregroundStyle(theme.linkColor)
          }
          .accessibilityLabel(Text("cancel_button".localized))
        }
      }
    }
  }

  static var footerClearance: CGFloat { 88 }
}

// MARK: - Screen 2 · Method

/// "How do you want to sign in?" — rendered only when the server offers an alternative. The
/// alternative is primary; the password path, when the server accepts one at all, is secondary.
struct IntegrationMethodScreen<VM: IntegrationConnectionViewModelProtocol>: View {
  @ObservedObject var viewModel: VM

  let isLoading: Bool
  var onStartAlternative: () -> Void

  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    ZStack(alignment: .bottom) {
      Form {
        ThemedSection {
          // Just the URL, no "URL" label: a key/value pair in a grouped list reads as a tappable
          // row, and this one is purely informational. The bare value gets the full width — these
          // are often long self-hosted hostnames — and wraps rather than truncating.
          Text(viewModel.form.serverUrl)
            .bpFont(.footnote)
            .foregroundStyle(theme.secondaryColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
          if !viewModel.form.customHeaders.isEmpty {
            NavigationLink(value: ConnectionFlowStep.headersDetail) {
              HStack {
                Text("integration_custom_headers_title".localized)
                  .foregroundStyle(theme.primaryColor)
                Spacer()
                Text("\(viewModel.form.customHeaders.count)")
                  .foregroundStyle(theme.secondaryColor)
              }
            }
          }
        }
      }
      .applyListStyle(with: theme, background: theme.systemBackgroundColor)
      .safeAreaInset(edge: .bottom) {
        Color.clear.frame(height: IntegrationAddressScreen<VM>.footerClearance)
      }

      VStack(spacing: Spacing.S) {
        IntegrationFlowPrimaryButton(title: primaryTitle, isDisabled: isLoading) {
          onStartAlternative()
        }
        if viewModel.supportsPasswordSignIn {
          Button {
            viewModel.flowPath.append(.password)
          } label: {
            Text("integration_password_signin_button".localized)
              .bpFont(.body)
              .frame(maxWidth: .infinity)
              .foregroundColor(theme.linkColor)
          }
          .padding(.bottom, Spacing.S)
        }
      }
    }
    .navigationTitle(navigationTitle)
    .navigationBarTitleDisplayMode(.inline)
  }

  /// The server's own name when the admin set one; the host otherwise — a blank title helps nobody.
  private var navigationTitle: String {
    if !viewModel.form.serverName.isEmpty { return viewModel.form.serverName }
    return IntegrationServerAddress(parsing: viewModel.form.serverUrl)?.hostField
      ?? viewModel.form.serverUrl
  }

  private var primaryTitle: String {
    switch viewModel.alternativeSignIn {
    case .oidc(let buttonText):
      return buttonText ?? "integration_sso_button".localized
    case .quickConnect:
      return "integration_quick_connect_button".localized
    case nil:
      // Unreachable by routing: `.method` is only pushed when an alternative exists.
      return "integration_sign_in_button".localized
    }
  }
}

// MARK: - Screen 3 · Password

struct IntegrationPasswordScreen<VM: IntegrationConnectionViewModelProtocol>: View {
  @ObservedObject var viewModel: VM

  let isLoading: Bool
  var onSignIn: () -> Void

  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    ZStack(alignment: .bottom) {
      Form {
        // Typing is the only thing this screen does, so the username field always auto-focuses.
        IntegrationServerFoundView(
          username: $viewModel.form.username,
          password: $viewModel.form.password,
          autoFocusesUsername: true,
          onCommit: onSignIn
        )
      }
      .applyListStyle(with: theme, background: theme.systemBackgroundColor)
      .safeAreaInset(edge: .bottom) {
        Color.clear.frame(height: IntegrationAddressScreen<VM>.footerClearance)
      }

      IntegrationFlowPrimaryButton(
        title: "integration_sign_in_button".localized,
        isDisabled: viewModel.form.username.isEmpty || viewModel.form.password.isEmpty || isLoading,
        action: onSignIn
      )
    }
    .navigationTitle("integration_sign_in_button".localized)
    .navigationBarTitleDisplayMode(.inline)
  }
}

// MARK: - Headers detail

/// Read-only view of the headers the connection carries. A pushed screen rather than an alert:
/// alerts don't scroll, truncate long values, and can't be copied — and these are frequently secrets,
/// which is the whole reason custom headers exist. Values render in full; nothing in a
/// `[String: String]` says which value is a credential, so any masking rule would be guesswork.
struct IntegrationHeadersDetailScreen: View {
  let headers: [CustomHeaderEntry]

  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    Form {
      IntegrationHeadersReadOnlySection(headers: headers)
    }
    .applyListStyle(with: theme, background: theme.systemBackgroundColor)
    .navigationTitle("integration_custom_headers_title".localized)
    .navigationBarTitleDisplayMode(.inline)
  }
}

/// Read-only rendering of a connection's custom headers — shared by the flow's pushed detail and the
/// connection-details screen, whose editor is gone (edits happen on the flow's address screen).
struct IntegrationHeadersReadOnlySection: View {
  let headers: [CustomHeaderEntry]

  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    if !headers.isEmpty {
      ThemedSection {
        ForEach(headers) { header in
          VStack(alignment: .leading, spacing: 4) {
            Text(header.key)
              .bpFont(.footnote)
              .foregroundStyle(theme.secondaryColor)
            Text(header.value)
              .bpFont(.body)
              .foregroundStyle(theme.primaryColor)
              .textSelection(.enabled)
          }
        }
      } header: {
        Text("integration_custom_headers_title".localized)
          .foregroundStyle(theme.secondaryColor)
      } footer: {
        Text("integration_headers_detail_footer".localized)
          .foregroundStyle(theme.secondaryColor)
      }
    }
  }
}

// MARK: - Shared chrome

/// The flow's pinned primary action — filled, full width, bottom of every screen, so the way forward
/// never moves and never vanishes.
struct IntegrationFlowPrimaryButton: View {
  let title: String
  var isDisabled: Bool = false
  var action: () -> Void

  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    Button(action: action) {
      Text(title)
        .bpFont(.headline)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(theme.linkColor)
        .foregroundColor(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .disabledWithOpacity(isDisabled)
    .padding(.horizontal, Spacing.M)
    .padding(.bottom, Spacing.S)
  }
}
