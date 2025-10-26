//
//  SmartRewindSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 27/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct SmartRewindSectionView: View {
  @AppStorage(Constants.UserDefaults.smartRewindEnabled) var smartRewindEnabled: Bool = true
  @AppStorage(Constants.UserDefaults.smartRewindMaxInterval) var smartRewindMaxInterval: TimeInterval = 30

  @EnvironmentObject var theme: ThemeViewModel

  private let intervals: [TimeInterval] = [
    2.0,
    5.0,
    10.0,
    15.0,
    20.0,
    30.0,
    45.0,
    60.0,
    90.0,
    120.0,
    180.0,
    240.0,
    300.0,
  ]

  var body: some View {
    Section {
      Toggle("settings_smartrewind_title", isOn: $smartRewindEnabled)
      if smartRewindEnabled {
        Picker("settings_smartrewind_max_interval_title", selection: $smartRewindMaxInterval) {
          ForEach(intervals, id: \.self) { interval in
            Text(
              TimeParser.formatDuration(interval)
            ).tag(interval)
              .foregroundStyle(theme.linkColor)
          }
        }
        .pickerStyle(.menu)
      }
    } footer: {
      Text(String(format: "settings_smartrewind_description".localized, TimeParser.formatDuration(smartRewindMaxInterval)))
        .foregroundStyle(theme.secondaryColor)
    }
  }
}

#Preview {
  Form {
    SmartRewindSectionView()
  }
  .environmentObject(ThemeViewModel())
}
