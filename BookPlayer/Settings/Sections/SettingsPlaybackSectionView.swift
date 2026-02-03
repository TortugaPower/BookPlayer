//
//  SettingsPlaybackSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 19/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct SettingsPlaybackSectionView: View {
  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    Section {
      NavigationLink(value: SettingsScreen.controls) {
        Text("settings_controls_title")
          .bpFont(.body)
      }
      NavigationLink(value: SettingsScreen.autoplay) {
        Text("settings_autoplay_section_title".localized.localizedCapitalized)
          .bpFont(.body)
      }
      NavigationLink(value: SettingsScreen.autolock) {
        Text("settings_autlock_section_title")
          .bpFont(.body)
      }
    } header: {
      Text("settings_playback_title")
        .bpFont(.subheadline)
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
