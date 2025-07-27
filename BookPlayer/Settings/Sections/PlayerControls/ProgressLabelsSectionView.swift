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
  @AppStorage(Constants.UserDefaults.remainingTimeEnabled) var prefersRemainingTime: Bool = true
  @AppStorage(Constants.UserDefaults.chapterContextEnabled) var prefersChapterContext: Bool = true

  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    Section {
      Toggle("settings_remainingtime_title", isOn: $prefersRemainingTime)
        .onChange(of: prefersRemainingTime) {
          handleValueUpdated()
        }
      Toggle("settings_chaptercontext_title", isOn: $prefersChapterContext)
        .onChange(of: prefersChapterContext) {
          handleValueUpdated()
        }
    } header: {
      Text("settings_progresslabels_title")
        .foregroundStyle(theme.secondaryColor)
    } footer: {
      Text("settings_progresslabels_description")
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
