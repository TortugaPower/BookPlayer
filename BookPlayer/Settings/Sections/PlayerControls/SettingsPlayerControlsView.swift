//
//  SettingsPlayerControlsView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 27/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct SettingsPlayerControlsView: View {
  @StateObject var theme = ThemeViewModel()

  var body: some View {
    Form {
      SkipIntervalsSectionView()
      SmartRewindSectionView()
      AutoSleepTimerSectionView()
      BoostVolumeSectionView()
      GlobalSpeedSectionView()
      ProgressSeekingSectionView()
      ListOptionsSectionView()
      ProgressLabelsSectionView()
    }
    .environmentObject(theme)
    .scrollContentBackground(.hidden)
    .background(theme.systemBackgroundColor)
    .listRowBackground(theme.systemGroupedBackgroundColor)
    .navigationTitle("settings_controls_title")
    .navigationBarTitleDisplayMode(.inline)
  }
}

#Preview {
  NavigationStack {
    SettingsPlayerControlsView()
  }
}
