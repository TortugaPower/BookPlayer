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
      Toggle(isOn: $autoTimerEnabled) {
        Text("settings_sleeptimer_auto_title")
          .bpFont(.body)
      }
    } footer: {
      Text("settings_sleeptimer_auto_description")
        .bpFont(.caption)
        .foregroundStyle(theme.secondaryColor)
    }
    .listRowBackground(theme.tertiarySystemBackgroundColor)
  }
}

#Preview {
  Form {
    AutoSleepTimerSectionView()
  }
  .environmentObject(ThemeViewModel())
}
