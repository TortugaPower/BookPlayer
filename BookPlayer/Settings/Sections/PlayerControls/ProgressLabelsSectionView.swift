//
//  ProgressLabelsSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 27/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct ProgressLabelsSectionView: View {
  @AppStorage(Constants.UserDefaults.remainingTimeEnabled, store: UserDefaults.sharedDefaults) var prefersRemainingTime: Bool = true
  @AppStorage(Constants.UserDefaults.chapterContextEnabled, store: UserDefaults.sharedDefaults) var prefersChapterContext: Bool = true

  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    Section {
      Toggle(isOn: $prefersRemainingTime) {
        Text("settings_remainingtime_title")
          .bpFont(.body)
      }
      .onChange(of: prefersRemainingTime) {
        handleValueUpdated()
      }
      Toggle(isOn: $prefersChapterContext) {
        Text("settings_chaptercontext_title")
          .bpFont(.body)
      }
      .onChange(of: prefersChapterContext) {
        handleValueUpdated()
      }
    } header: {
      Text("settings_progresslabels_title")
        .bpFont(.subheadline)
        .foregroundStyle(theme.secondaryColor)
    } footer: {
      Text("settings_progresslabels_description")
        .bpFont(.caption)
        .foregroundStyle(theme.secondaryColor)
    }
  }

  func handleValueUpdated() {
    /// Notify player screen
    UserDefaults.standard.set(true, forKey: Constants.UserDefaults.updateProgress)
  }
}

#Preview {
  Form {
    ProgressLabelsSectionView()
  }
  .environmentObject(ThemeViewModel())
}
