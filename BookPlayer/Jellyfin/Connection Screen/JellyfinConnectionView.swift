//
//  JellyfinConnectionView.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-10-25.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

enum JellyfinConnectionViewField: Focusable {
  case none
  case serverUrl, username, password
}

struct JellyfinConnectionView: View {
  /// View model for the form
  @ObservedObject var viewModel: JellyfinConnectionViewModel

  @State private var firstAppear = true
  @State private var isLoading = false
  @State private var error: Error?

  @EnvironmentObject var theme: ThemeViewModel

  @Environment(\.dismiss) var dismiss

  var body: some View {
    Form {
      switch viewModel.connectionState {
      case .disconnected:
        JellyfinDisconnectedView(
          serverUrl: $viewModel.form.serverUrl,
          onCommit: onConnect
        )
      case .foundServer:
        JellyfinServerInformationSectionView(
          serverName: viewModel.form.serverName,
          serverUrl: viewModel.form.serverUrl
        )
        JellyfinServerFoundView(
          username: $viewModel.form.username,
          password: $viewModel.form.password,
          onCommit: onSignIn
        )
      case .connected:
        JellyfinServerInformationSectionView(
          serverName: viewModel.form.serverName,
          serverUrl: viewModel.form.serverUrl
        )
        JellyfinConnectedView(viewModel: viewModel)
      }
    }
    .scrollContentBackground(.hidden)
    .background(theme.systemGroupedBackgroundColor)
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
          .font(.headline)
          .foregroundStyle(theme.primaryColor)
      }
      ToolbarItemGroup(placement: .confirmationAction) {
        switch (viewModel.viewMode, viewModel.connectionState) {
        case (_, .disconnected):
          connectToolbarButton
        case (_, .foundServer):
          signInToolbarButton
        case (.regular, .connected):
          goToLibraryToolbarButton
        case (.viewDetails, .connected):
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
    case .disconnected, .foundServer: "Jellyfin"
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

  @ViewBuilder
  private var goToLibraryToolbarButton: some View {
    Button(
      "library_title",
      systemImage: "chevron.forward",
      action: viewModel.handleGoToLibraryAction
    )
    .foregroundStyle(theme.linkColor)
  }
}

#Preview("disconnected") {
  let viewModel = JellyfinConnectionViewModel(
    connectionService: JellyfinConnectionService(),
    navigation: BPNavigation()
  )
  JellyfinConnectionView(viewModel: viewModel)
    .environmentObject(ThemeViewModel())
}

#Preview("found server") {
  let viewModel = {
    let viewModel = JellyfinConnectionViewModel(
      connectionService: JellyfinConnectionService(),
      navigation: BPNavigation()
    )
    viewModel.connectionState = .foundServer
    viewModel.form.serverName = "Mock Server"
    viewModel.form.serverUrl = "http://example.com"
    return viewModel
  }()
  JellyfinConnectionView(viewModel: viewModel)
    .environmentObject(ThemeViewModel())
}

#Preview("connected") {
  let viewModel = {
    let viewModel = JellyfinConnectionViewModel(
      connectionService: JellyfinConnectionService(),
      navigation: BPNavigation()
    )
    viewModel.connectionState = .connected
    viewModel.form.serverName = "Mock Server"
    viewModel.form.serverUrl = "http://example.com"
    viewModel.form.username = "Mock User"
    viewModel.form.password = "secret"
    return viewModel
  }()
  JellyfinConnectionView(viewModel: viewModel)
    .environmentObject(ThemeViewModel())
}
