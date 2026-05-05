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

  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    Form {
      switch viewModel.connectionState {
      case .disconnected:
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
      case .foundServer:
        IntegrationServerInformationSectionView(
          serverName: viewModel.form.serverName,
          serverUrl: viewModel.form.serverUrl
        )
        IntegrationServerFoundView(
          username: $viewModel.form.username,
          password: $viewModel.form.password,
          onCommit: onSignIn
        )
        IntegrationCustomHeadersSectionView(
          customHeaders: $viewModel.form.customHeaders
        )
      case .connected:
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
      ToolbarItem(placement: .principal) {
        Text(localizedNavigationTitle)
          .bpFont(.headline)
          .foregroundStyle(theme.primaryColor)
      }
      ToolbarItemGroup(placement: .confirmationAction) {
        switch viewModel.connectionState {
        case .disconnected:
          connectToolbarButton
        case .foundServer:
          signInToolbarButton
        case .connected:
          EmptyView()
        }
      }
    }
    .tint(theme.linkColor)
  }

  // MARK: Utils

  func onConnect() {
    isLoading = true
    Task {
      do {
        try await viewModel.handleConnectAction()
        isLoading = false
      } catch {
        isLoading = false
        self.error = error
      }
    }
  }

  func onSignIn() {
    isLoading = true
    Task {
      do {
        try await viewModel.handleSignInAction()
        isLoading = false
      } catch {
        isLoading = false
        self.error = error
      }
    }
  }

  // MARK: - Navigation Title

  private var localizedNavigationTitle: String {
    switch viewModel.connectionState {
    case .disconnected, .foundServer: integrationName
    case .connected: "integration_connection_details_title".localized
    }
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
