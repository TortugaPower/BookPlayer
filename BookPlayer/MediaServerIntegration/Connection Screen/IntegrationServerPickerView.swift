//
//  IntegrationServerPickerView.swift
//  BookPlayer
//
//  Created by Matthew Alnaser on 2026-04-06.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

/// Server picker shown in the import flow when 2+ servers are saved.
/// Tap a server to activate it and navigate to its library.
struct IntegrationServerPickerView<VM: IntegrationConnectionViewModelProtocol>: View {
  @ObservedObject var viewModel: VM
  let onServerSelected: (String) -> Void

  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    Form {
      ThemedSection {
        ForEach(viewModel.servers) { server in
          Button {
            onServerSelected(server.id)
          } label: {
            HStack {
              VStack(alignment: .leading) {
                Text(server.serverName)
                  .foregroundStyle(theme.primaryColor)
                Text(server.serverUrl)
                  .font(.caption)
                  .foregroundStyle(theme.secondaryColor)
              }
              Spacer()
              if server.isActive {
                Image(systemName: "checkmark")
                  .foregroundStyle(theme.linkColor)
              }
            }
          }
          .accessibilityLabel("\(server.serverName), \(server.serverUrl)")
        }
      } header: {
        Text("integration_section_login".localized)
          .foregroundStyle(theme.secondaryColor)
      }
    }
    .scrollContentBackground(.hidden)
    .background(theme.systemBackgroundColor)
  }
}
