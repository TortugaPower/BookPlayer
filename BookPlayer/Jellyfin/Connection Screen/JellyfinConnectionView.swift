//
//  JellyfinConnectionView.swift
//  BookPlayer
//
//  Created by Lysann Schlegel on 2024-10-25.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import SwiftUI

struct JellyfinConnectionView: View {
  /// View model for the form
  @ObservedObject var viewModel: JellyfinConnectionViewModel
  /// Theme view model to update colors
  @StateObject var themeViewModel = ThemeViewModel()

  struct DisconnectedView: View {
    var serverUrl: Binding<String>
    @EnvironmentObject var themeViewModel: ThemeViewModel

    var body: some View {
      Section {
        ClearableTextField("jellyfin_server_url_placeholder".localized, text: serverUrl) {
          $0.keyboardType = .URL
          $0.textContentType = .URL
          $0.autocapitalization = .none
        }
      } header: {
        Text("jellyfin_section_server_url".localized)
          .foregroundColor(themeViewModel.secondaryColor)
      } footer: {
        Text("jellyfin_section_server_url_footer".localized)
          .foregroundColor(themeViewModel.secondaryColor)
      }
    }
  }

  struct FoundServerView: View {
    var serverUrl: String
    var serverName: String
    var username: Binding<String>
    var password: Binding<String>
    @EnvironmentObject var themeViewModel: ThemeViewModel

    var body: some View {
      Section {
        HStack {
          Text("jellyfin_server_name_label".localized)
            .foregroundColor(themeViewModel.secondaryColor)
          Spacer()
          Text(serverName)
        }
        HStack {
          Text("jellyfin_server_url_label".localized)
            .foregroundColor(themeViewModel.secondaryColor)
          Spacer()
          Text(serverUrl)
        }
      } header: {
        Text("jellyfin_section_server".localized)
      }
      Section {
        ClearableTextField("jellyfin_username_placeholder".localized, text: username) {
          $0.textContentType = .name
          $0.autocapitalization = .none
        }
        ClearableTextField("jellyfin_password_placeholder".localized, text: password) {
          $0.textContentType = .password
          $0.autocapitalization = .none
        }
      } header: {
        Text("jellyfin_section_login".localized)
      }
    }
  }

  struct ConnectedView: View {
    var body: some View {
      EmptyView()
    }
  }

  var body: some View {
    Form {
      switch viewModel.connectionState {
      case .disconnected:
        DisconnectedView(serverUrl: $viewModel.form.serverUrl)
      case .foundServer:
        FoundServerView(
          serverUrl: viewModel.form.serverUrl,
          serverName: viewModel.form.serverName ?? "",
          username: $viewModel.form.username,
          password: $viewModel.form.password
        )
      case .connected:
        ConnectedView()
      }
    }
    .environmentObject(themeViewModel)
  }
}

#Preview {
  var viewModel = JellyfinConnectionViewModel()
  JellyfinConnectionView(viewModel: viewModel)
}
