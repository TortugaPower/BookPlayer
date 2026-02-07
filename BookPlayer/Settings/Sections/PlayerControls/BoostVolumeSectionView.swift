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
  @EnvironmentObject private var playerManager: PlayerManager

  var body: some View {
    ThemedSection {
      Toggle(isOn: $boostVolumeEnabled) {
        Text("settings_boostvolume_title")
          .bpFont(.body)
      }
      .onChange(of: boostVolumeEnabled) {
        playerManager.setBoostVolume(boostVolumeEnabled)
      }
    } footer: {
      Text("settings_boostvolume_description")
        .bpFont(.caption)
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
