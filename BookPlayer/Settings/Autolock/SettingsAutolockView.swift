//
//  SettingsAutolockView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/1/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct SettingsAutolockView: View {

  @EnvironmentObject var theme: ThemeViewModel
  @StateObject var viewModel = SettingsAutolockViewModel()

  var body: some View {
    formView
      .defaultFormBackground()
  }

  var formView: some View {
    Form {
      ThemedSection {
        Toggle(
          isOn: $viewModel.autolockDisabled,
          label: {
            Text("settings_autolock_title".localized)
              .foregroundStyle(theme.primaryColor)
          }
        )
        Toggle(
          isOn: $viewModel.onlyWhenPoweredEnabled,
          label: {
            Text("settings_power_connected_title".localized)
              .foregroundStyle(theme.primaryColor)
          }
        )
        .disabled(!viewModel.autolockDisabled)
      } footer: {
        Text("settings_autolock_description".localized)
          .foregroundStyle(theme.secondaryColor)
      }
    }
    .scrollContentBackground(.hidden)
    .background(theme.systemBackgroundColor)
    .navigationTitle(viewModel.navigationTitle)
    .navigationBarTitleDisplayMode(.inline)
  }
}

struct SettingsAutolockViewView_Previews: PreviewProvider {
  static var previews: some View {
    SettingsAutolockView()
  }
}
