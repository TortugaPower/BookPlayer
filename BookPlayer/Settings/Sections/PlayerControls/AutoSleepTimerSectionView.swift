//
//  AutoSleepTimerSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 27/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct AutoSleepTimerSectionView: View {
  @AppStorage(Constants.UserDefaults.autoTimerEnabled) var autoTimerEnabled: Bool = false

  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    Section {
      Toggle("settings_sleeptimer_auto_title", isOn: $autoTimerEnabled)
        .tint(theme.linkColor)
    } footer: {
      Text("settings_sleeptimer_auto_description")
        .foregroundStyle(theme.secondaryColor)
    }
  }
}

#Preview {
  Form {
    AutoSleepTimerSectionView()
  }
  .environmentObject(ThemeViewModel())
}
