//
//  SettingsAutoplayView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 8/1/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct SettingsAutoplayView<Model: SettingsAutoplayViewModelProtocol>: View {

  @StateObject var themeViewModel = ThemeViewModel()
  @ObservedObject var viewModel: Model

  var body: some View {
    formView
      .defaultFormBackground()
  }

  var formView: some View {
    Form {
      Section {
        Toggle(isOn: $viewModel.autoplayLibraryEnabled, label: {
          Text("settings_autoplay_title".localized)
            .foregroundStyle(themeViewModel.primaryColor)
        })
        Toggle(isOn: $viewModel.autoplayRestartFinishedEnabled, label: {
          Text("settings_autoplay_restart_title".localized)
            .foregroundStyle(themeViewModel.primaryColor)
        })
        .disabled(!viewModel.autoplayLibraryEnabled)
      } footer: {
        Text("settings_autoplay_description".localized)
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

struct SettingsAutoplayView_Previews: PreviewProvider {
  static var previews: some View {
    SettingsAutoplayView(viewModel: SettingsAutoplayViewModel())
  }
}
