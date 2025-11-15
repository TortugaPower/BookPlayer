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
        Text("audiobookshelf_username_placeholder".localized)
          .foregroundStyle(theme.secondaryColor)
        Spacer()
        Text(viewModel.form.username)
      }
    } header: {
      Text("audiobookshelf_section_login".localized)
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
