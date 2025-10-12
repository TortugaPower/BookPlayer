//
//  SkipIntervalsSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 27/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import MediaPlayer
import SwiftUI

struct SkipIntervalsSectionView: View {
  @AppStorage(Constants.UserDefaults.rewindInterval) var rewindInterval: TimeInterval = 30
  @AppStorage(Constants.UserDefaults.forwardInterval) var forwardInterval: TimeInterval = 30
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
      Picker("settings_skip_rewind_title", selection: $rewindInterval) {
        ForEach(intervals, id: \.self) { interval in
          Text(
            TimeParser.formatDuration(interval)
          ).tag(interval)
            .foregroundStyle(theme.linkColor)
        }
      }
      .pickerStyle(.menu)
      .onChange(of: rewindInterval) {
        MPRemoteCommandCenter.shared().skipBackwardCommand.preferredIntervals = [rewindInterval] as [NSNumber]
      }

      Picker("settings_skip_forward_title", selection: $forwardInterval) {
        ForEach(intervals, id: \.self) { interval in
          Text(
            TimeParser.formatDuration(interval)
          ).tag(interval)
            .foregroundStyle(theme.linkColor)
        }
      }
      .pickerStyle(.menu)
      .onChange(of: forwardInterval) {
        MPRemoteCommandCenter.shared().skipForwardCommand.preferredIntervals = [forwardInterval] as [NSNumber]
      }
    } header: {
      Text("settings_skip_title".localized.capitalized)
        .foregroundStyle(theme.secondaryColor)
    } footer: {
      Text("settings_skip_description")
        .foregroundStyle(theme.secondaryColor)
    }
  }
}

#Preview {
  Form {
    SkipIntervalsSectionView()
  }
  .environmentObject(ThemeViewModel())
}
