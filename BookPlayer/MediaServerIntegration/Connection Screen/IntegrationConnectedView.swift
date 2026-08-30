//
//  IntegrationConnectedView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/5/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

/// In-library "Connection Details" view: shows only the *active* connection's
/// username and a Log out action. Multi-server management lives in
/// `MediaServersView`, not here.
struct IntegrationConnectedView<VM: IntegrationConnectionViewModelProtocol>: View {
  @ObservedObject var viewModel: VM
  @EnvironmentObject var theme: ThemeViewModel
  @Environment(\.dismiss) private var dismiss

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
        // Signing out is deletion: the connection this screen describes no longer exists, so the
        // screen leaves with it — back to Media Servers (sheet) or the presenting stack (push).
        // The old behavior redrew the details sheet into the sign-in form in place.
        dismiss()
      }
      .frame(maxWidth: .infinity)
      .foregroundStyle(.red)
    }
  }
}
