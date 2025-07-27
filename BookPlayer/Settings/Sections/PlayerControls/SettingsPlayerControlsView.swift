//
//  SettingsPlayerControlsView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 27/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct SettingsPlayerControlsView: View {
  @EnvironmentObject var theme: ThemeViewModel

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
    .scrollContentBackground(.hidden)
    .background(theme.systemGroupedBackgroundColor)
    .listRowBackground(theme.secondarySystemBackgroundColor)
    .navigationTitle("settings_controls_title")
    .navigationBarTitleDisplayMode(.inline)
  }
}

#Preview {
  NavigationStack {
    SettingsPlayerControlsView()
      .environmentObject(ThemeViewModel())
  }
}
