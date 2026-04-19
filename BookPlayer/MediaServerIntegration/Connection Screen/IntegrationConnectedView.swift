//
//  IntegrationConnectedView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/5/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct IntegrationConnectedView<VM: IntegrationConnectionViewModelProtocol>: View {
  @ObservedObject var viewModel: VM
  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    if viewModel.servers.count <= 1 {
      // Single server: show the original simple layout
      ThemedSection {
        HStack {
          Text("integration_username_placeholder".localized)
            .foregroundStyle(theme.secondaryColor)
          Spacer()
          Text(viewModel.form.username)
        }
      } header: {
        Text("integration_section_login".localized)
          .foregroundStyle(theme.secondaryColor)
      }

      ThemedSection {
        Button("logout_title".localized, role: .destructive) {
          viewModel.handleSignOutAction()
        }
        .frame(maxWidth: .infinity)
        .foregroundStyle(.red)
      }
    } else {
      // Multiple servers: show all servers with per-server actions
      ThemedSection {
        ForEach(viewModel.servers) { server in
          VStack(alignment: .leading, spacing: 4) {
            HStack {
              VStack(alignment: .leading) {
                Text(server.serverName)
                  .foregroundStyle(theme.primaryColor)
                Text("\(server.userName) — \(server.serverUrl)")
                  .font(.caption)
                  .foregroundStyle(theme.secondaryColor)
              }
              Spacer()
              if server.isActive {
                Image(systemName: "checkmark")
                  .foregroundStyle(theme.linkColor)
                  .accessibilityLabel("Active")
              }
            }
            Button("logout_title".localized, role: .destructive) {
              viewModel.handleSignOutAction(id: server.id)
            }
            .font(.caption)
            .foregroundStyle(.red)
          }
          .padding(.vertical, 4)
        }
      } header: {
        Text("integration_section_login".localized)
          .foregroundStyle(theme.secondaryColor)
      }
    }

    ThemedSection {
      Button {
        viewModel.handleAddServerAction()
      } label: {
        Label("integration_add_server_button".localized, systemImage: "plus.circle")
      }
    }
  }
}
