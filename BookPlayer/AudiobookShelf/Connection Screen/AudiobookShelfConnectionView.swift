//
//  AudiobookShelfConnectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/14/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

enum AudiobookShelfConnectionViewField: Focusable {
  case none
  case serverUrl, username, password
}

struct AudiobookShelfConnectionView: View {
  /// View model for the form
  @ObservedObject var viewModel: AudiobookShelfConnectionViewModel

  @State private var firstAppear = true
  @State private var isLoading = false
  @State private var error: Error?

  @EnvironmentObject var theme: ThemeViewModel

  @Environment(\.dismiss) var dismiss

  var body: some View {
    Form {
      switch viewModel.connectionState {
      case .disconnected:
        AudiobookShelfDisconnectedView(
          serverUrl: $viewModel.form.serverUrl,
          onCommit: onConnect
        )
      case .foundServer:
        AudiobookShelfServerInformationSectionView(
          serverName: viewModel.form.serverName,
          serverUrl: viewModel.form.serverUrl
        )
        AudiobookShelfServerFoundView(
          username: $viewModel.form.username,
          password: $viewModel.form.password,
          onCommit: onSignIn
        )
      case .connected:
        AudiobookShelfServerInformationSectionView(
          serverName: viewModel.form.serverName,
          serverUrl: viewModel.form.serverUrl
        )
        AudiobookShelfConnectedView(viewModel: viewModel)
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
    case .disconnected, .foundServer: "AudiobookShelf"
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
      "library_title".localized,
      systemImage: "chevron.forward",
      action: viewModel.handleGoToLibraryAction
    )
    .foregroundStyle(theme.linkColor)
  }
}

#Preview("disconnected") {
  let viewModel = AudiobookShelfConnectionViewModel(
    connectionService: AudiobookShelfConnectionService(),
    navigation: BPNavigation()
  )
  AudiobookShelfConnectionView(viewModel: viewModel)
    .environmentObject(ThemeViewModel())
}

#Preview("found server") {
  let viewModel = {
    let viewModel = AudiobookShelfConnectionViewModel(
      connectionService: AudiobookShelfConnectionService(),
      navigation: BPNavigation()
    )
    viewModel.connectionState = .foundServer
    viewModel.form.serverName = "Mock Server"
    viewModel.form.serverUrl = "http://example.com"
    return viewModel
  }()
  AudiobookShelfConnectionView(viewModel: viewModel)
    .environmentObject(ThemeViewModel())
}

#Preview("connected") {
  let viewModel = {
    let viewModel = AudiobookShelfConnectionViewModel(
      connectionService: AudiobookShelfConnectionService(),
      navigation: BPNavigation()
    )
    viewModel.connectionState = .connected
    viewModel.form.serverName = "Mock Server"
    viewModel.form.serverUrl = "http://example.com"
    viewModel.form.username = "Mock User"
    viewModel.form.password = "secret"
    return viewModel
  }()
  AudiobookShelfConnectionView(viewModel: viewModel)
    .environmentObject(ThemeViewModel())
}
