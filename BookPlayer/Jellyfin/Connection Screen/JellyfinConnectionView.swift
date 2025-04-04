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
  /// Theme view model to update colors
  @StateObject var themeViewModel = ThemeViewModel()
  
  @State var focusedField: JellyfinConnectionViewField = .none
  
  var body: some View {
    Form {
      switch viewModel.connectionState {
      case .disconnected: disconnectedView
      case .foundServer: foundServerView
      case .connected: connectedView
      }
    }
    .defaultFormBackground()
    .environmentObject(themeViewModel)
    .navigationTitle(localizedNavigationTitle)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItemGroup(placement: .cancellationAction) {
        cancelToolbarButton
      }
      ToolbarItemGroup(placement: .confirmationAction) {
        if viewModel.viewMode == .regular {
          switch viewModel.connectionState {
          case .disconnected:
            connectToolbarButton
          case .foundServer:
            signInToolbarButton
          case .connected:
            goToLibraryToolbarButton
          }
        }
      }
    }
  }
  
  // MARK: - View

  @ViewBuilder
  private var disconnectedView: some View {
    Section {
      ClearableTextField("http://jellyfin.example.com:8096", text: $viewModel.form.serverUrl, onCommit: {
        if viewModel.canConnect {
          viewModel.handleConnectAction()
        }
      })
      .keyboardType(.URL)
      .textContentType(.URL)
      .autocapitalization(.none)
      .focused($focusedField, selfKey: .serverUrl)
    } header: {
      Text("jellyfin_section_server_url".localized)
        .foregroundColor(themeViewModel.secondaryColor)
    } footer: {
      Text("jellyfin_section_server_url_footer".localized)
        .foregroundColor(themeViewModel.secondaryColor)
    }
    .listRowBackground(themeViewModel.secondarySystemBackgroundColor)
    .onAppear {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        focusedField = .serverUrl
      }
    }
  }

  @ViewBuilder
  private var foundServerView: some View {
    serverInfoSection

    Section {
      ClearableTextField("jellyfin_username_placeholder".localized, text: $viewModel.form.username, onCommit: {
        focusedField = .password
      })
      .textContentType(.username)
      .autocapitalization(.none)
      .focused($focusedField, selfKey: .username)
      
      SecureField("jellyfin_password_placeholder".localized, text: $viewModel.form.password, onCommit: {
        if viewModel.canSignIn {
          viewModel.handleSignInAction()
        }
      })
      .textContentType(.password)
      .focused($focusedField, selfKey: .password)
      
      Toggle(isOn: $viewModel.form.rememberMe) {
        Text("jellyfin_password_remember_me_label".localized)
          .foregroundColor(themeViewModel.primaryColor)
      }
    } header: {
      Text("jellyfin_section_login".localized)
    }
    .listRowBackground(themeViewModel.secondarySystemBackgroundColor)
    .onAppear {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        focusedField = .username
      }
    }
  }

  @ViewBuilder
  private var connectedView: some View {
    serverInfoSection

    Section {
      HStack {
        Text("jellyfin_username_placeholder".localized)
          .foregroundColor(themeViewModel.secondaryColor)
        Spacer()
        Text(viewModel.form.username)
      }
    } header: {
      Text("jellyfin_section_login".localized)
    }
    .listRowBackground(themeViewModel.secondarySystemBackgroundColor)

    Section {
      destructiveButton("logout_title".localized) {
        viewModel.handleSignOutAction()
      }
      .frame(maxWidth: .infinity)
    }
    .listRowBackground(themeViewModel.secondarySystemBackgroundColor)
  }

  @ViewBuilder
  private var serverInfoSection: some View {
    Section {
      HStack {
        Text("jellyfin_server_name_label".localized)
          .foregroundColor(themeViewModel.secondaryColor)
        Spacer()
        Text(viewModel.form.serverName ?? "")
      }
      HStack {
        Text("jellyfin_server_url_label".localized)
          .foregroundColor(themeViewModel.secondaryColor)
        Spacer()
        Text(viewModel.form.serverUrl)
      }
    } header: {
      Text("jellyfin_section_server".localized)
    }
    .listRowBackground(themeViewModel.secondarySystemBackgroundColor)
  }
  
  // MARK: Utils

  @ViewBuilder
  private func destructiveButton(_ title: String, action: @escaping @MainActor () -> Void) -> some View {
    if #available(iOS 16.0, *) {
      Button(title, role: .destructive, action: action)
    } else {
      Button(title, action: action)
        .foregroundColor(destructiveRedColor)
    }
  }

  private var destructiveRedColor: Color {
    if UIColor.responds(to: Selector(("_systemDestructiveTintColor"))) {
      if let systemRed = UIColor.perform(Selector(("_systemDestructiveTintColor")))?.takeUnretainedValue() as? UIColor {
        return Color(systemRed)
      }
    }
    return .red
  }
  
  // MARK: - Navigation Title
  
  private var localizedNavigationTitle: String {
    switch viewModel.connectionState {
    case .disconnected, .foundServer: "Jellyfin"
    case .connected: "jellyfin_connection_details_title".localized
    }
  }
  
  // MARK: - Navigation Buttons
  
  @ViewBuilder
  private var cancelToolbarButton: some View {
    Button(
      action: viewModel.handleCancelAction,
      label: {
        Image(systemName: "xmark")
          .foregroundColor(themeViewModel.linkColor)
      }
    )
  }
  
  @ViewBuilder
  private var connectToolbarButton: some View {
    Button("jellyfin_connect_button".localized,
           action: viewModel.handleConnectAction
    )
    .disabled(!viewModel.canConnect)
  }
  
  @ViewBuilder
  private var signInToolbarButton: some View {
    Button("jellyfin_sign_in_button".localized,
           action: viewModel.handleSignInAction
    )
    .disabled(!viewModel.canSignIn)
  }
  
  @ViewBuilder
  private var goToLibraryToolbarButton: some View {
    Button("library_title".localized,
           systemImage: "chevron.right",
           action: viewModel.handleGoToLibraryAction
    )
    .disabled(!viewModel.canGoToLibrary)
  }
}

#Preview("disconnected") {
  let viewModel = JellyfinConnectionViewModel(jellyfinConnectionService: JellyfinConnectionService(keychainService: KeychainService()))
  JellyfinConnectionView(viewModel: viewModel)
}

#Preview("found server") {
  let viewModel = {
    let viewModel = JellyfinConnectionViewModel(jellyfinConnectionService: JellyfinConnectionService(keychainService: KeychainService()))
    viewModel.connectionState = .foundServer
    viewModel.form.serverName = "Mock Server"
    viewModel.form.serverUrl = "http://example.com"
    return viewModel
  }()
  JellyfinConnectionView(viewModel: viewModel)
}

#Preview("connected") {
  let viewModel = {
    let viewModel = JellyfinConnectionViewModel(jellyfinConnectionService: JellyfinConnectionService(keychainService: KeychainService()))
    viewModel.connectionState = .connected
    viewModel.form.serverName = "Mock Server"
    viewModel.form.serverUrl = "http://example.com"
    viewModel.form.username = "Mock User"
    viewModel.form.password = "secret"
    return viewModel
  }()
  JellyfinConnectionView(viewModel: viewModel)
}
