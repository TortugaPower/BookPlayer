//
//  SettingsAutolockView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/1/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct SettingsAutolockView<Model: SettingsAutolockViewModelProtocol>: View {

  @StateObject var themeViewModel = ThemeViewModel()
  @ObservedObject var viewModel: Model

  var body: some View {
    formView
      .defaultFormBackground()
  }

  var formView: some View {
    Form {
      Section {
        Toggle(isOn: $viewModel.autolockDisabled, label: {
          Text("settings_autolock_title".localized)
            .foregroundStyle(themeViewModel.primaryColor)
        })
        Toggle(isOn: $viewModel.onlyWhenPoweredEnabled, label: {
          Text("settings_power_connected_title".localized)
            .foregroundStyle(themeViewModel.primaryColor)
        })
        .disabled(!viewModel.autolockDisabled)
      } footer: {
        Text("settings_autolock_description".localized)
          .foregroundStyle(themeViewModel.secondaryColor)
      }
      .listRowBackground(themeViewModel.secondarySystemBackgroundColor)
    }
    .background(
      themeViewModel.systemGroupedBackgroundColor
        .edgesIgnoringSafeArea(.bottom)
    )
    .environmentObject(themeViewModel)
    .navigationTitle(viewModel.navigationTitle)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .navigationBarLeading) {
        Button(
          action: viewModel.dismiss,
          label: {
            Image(systemName: "xmark")
              .foregroundStyle(themeViewModel.linkColor)
          }
        )
      }
    }
  }
}

struct SettingsAutolockViewView_Previews: PreviewProvider {
  static var previews: some View {
    SettingsAutolockView(viewModel: SettingsAutolockViewModel())
  }
}
