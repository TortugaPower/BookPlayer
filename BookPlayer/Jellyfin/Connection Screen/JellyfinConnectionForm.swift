//
//  JellyfinConnectionForm.swift
//  BookPlayer
//
//  Created by Lysann Schlegel on 2024-10-25.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import SwiftUI

struct JellyfinConnectionForm: View {
  /// View model for the form
  @ObservedObject var viewModel: JellyfinConnectionFormViewModel
  /// Theme view model to update colors
  @StateObject var themeViewModel = ThemeViewModel()

  var body: some View {
    Form {
      Section {
        ClearableTextField("jellyfin_server_url_placeholder".localized, text: $viewModel.serverUrl) {
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
    .environmentObject(themeViewModel)
  }
}

#Preview {
  JellyfinConnectionForm(viewModel: JellyfinConnectionFormViewModel())
}
