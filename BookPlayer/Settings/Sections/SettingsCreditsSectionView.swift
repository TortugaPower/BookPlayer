//
//  SettingsCreditsSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 19/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct SettingsCreditsSectionView: View {
  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    ThemedSection {
      NavigationLink("settings_credits_title", value: SettingsScreen.credits)
        .settingsRowBackground(for: .credits)
    }
  }
}

#Preview {
  NavigationStack {
    Form {
      SettingsCreditsSectionView()
    }
  }
  .environmentObject(ThemeViewModel())
}
