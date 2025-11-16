//
//  AudiobookShelfConnectedView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/14/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct AudiobookShelfConnectedView: View {
  @ObservedObject var viewModel: AudiobookShelfConnectionViewModel
  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    Section {
      HStack {
        Text("integration_username_placeholder")
          .foregroundStyle(theme.secondaryColor)
        Spacer()
        Text(viewModel.form.username)
      }
    } header: {
      Text("integration_section_login")
        .foregroundStyle(theme.secondaryColor)
    }

    Section {
      Button("logout_title", role: .destructive) {
        viewModel.handleSignOutAction()
      }
      .frame(maxWidth: .infinity)
      .foregroundStyle(.red)
    }
  }
}
