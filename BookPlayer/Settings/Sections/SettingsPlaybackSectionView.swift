//
//  SettingsPlaybackSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 19/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct SettingsPlaybackSectionView: View {
  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    Section {
      NavigationLink("settings_controls_title", value: SettingsScreen.controls)
      NavigationLink("settings_autoplay_section_title".localized.localizedCapitalized, value: SettingsScreen.autoplay)
      NavigationLink("settings_autlock_section_title", value: SettingsScreen.autolock)
    } header: {
      Text("settings_playback_title")
        .foregroundStyle(theme.secondaryColor)
    }
  }
}

#Preview {
  NavigationStack {
    Form {
      SettingsPlaybackSectionView()
    }
  }
  .environmentObject(ThemeViewModel())
}
