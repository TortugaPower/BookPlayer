//
//  JellyfinConnectedView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 6/6/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct JellyfinConnectedView: View {
  @ObservedObject var viewModel: JellyfinConnectionViewModel
  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    Section {
      HStack {
        Text("jellyfin_username_placeholder".localized)
          .foregroundStyle(theme.secondaryColor)
        Spacer()
        Text(viewModel.form.username)
      }
    } header: {
      Text("jellyfin_section_login".localized)
        .foregroundStyle(theme.secondaryColor)
    }

    Section {
      Button("logout_title".localized, role: .destructive) {
        viewModel.handleSignOutAction()
      }
      .frame(maxWidth: .infinity)
      .foregroundStyle(.red)
    }
  }
}
