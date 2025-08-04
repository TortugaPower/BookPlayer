//
//  SettingsAutoplayView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 8/1/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct SettingsAutoplayView: View {

  @StateObject var theme = ThemeViewModel()
  @StateObject var viewModel = SettingsAutoplayViewModel()

  var body: some View {
    formView
      .defaultFormBackground()
  }

  var formView: some View {
    Form {
      Section {
        Toggle(
          isOn: $viewModel.autoplayLibraryEnabled,
          label: {
            Text("settings_autoplay_title".localized)
              .foregroundStyle(theme.primaryColor)
          }
        )
        Toggle(
          isOn: $viewModel.autoplayRestartFinishedEnabled,
          label: {
            Text("settings_autoplay_restart_title".localized)
              .foregroundStyle(theme.primaryColor)
          }
        )
        .disabled(!viewModel.autoplayLibraryEnabled)
      } footer: {
        Text("settings_autoplay_description".localized)
          .foregroundStyle(theme.secondaryColor)
      }
    }
    .scrollContentBackground(.hidden)
    .background(theme.systemGroupedBackgroundColor)
    .environmentObject(theme)
    .navigationTitle(viewModel.navigationTitle)
    .navigationBarTitleDisplayMode(.inline)
  }
}

struct SettingsAutoplayView_Previews: PreviewProvider {
  static var previews: some View {
    SettingsAutoplayView()
  }
}
