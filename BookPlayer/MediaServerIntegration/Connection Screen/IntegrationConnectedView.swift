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
  }
}
