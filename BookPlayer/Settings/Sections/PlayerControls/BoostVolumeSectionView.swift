//
//  BoostVolumeSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 27/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct BoostVolumeSectionView: View {
  @AppStorage(Constants.UserDefaults.boostVolumeEnabled) var boostVolumeEnabled: Bool = false

  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    Section {
      Toggle("settings_boostvolume_title", isOn: $boostVolumeEnabled)
        .tint(theme.linkColor)
        .onChange(of: boostVolumeEnabled) {
          /// TODO: change when playerManager is avaialble in the environment
          guard let playerManager = AppDelegate.shared?.coreServices?.playerManager else { return }

          playerManager.setBoostVolume(boostVolumeEnabled)
        }
    } footer: {
      Text("settings_boostvolume_description")
        .foregroundStyle(theme.secondaryColor)
    }
  }
}

#Preview {
  Form {
    BoostVolumeSectionView()
  }
  .environmentObject(ThemeViewModel())
}

