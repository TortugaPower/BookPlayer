//
//  VideoPlaybackSectionView.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 15/7/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct VideoPlaybackSectionView: View {
  @AppStorage(Constants.UserDefaults.videoBackgroundPlaybackEnabled)
  var videoBackgroundPlaybackEnabled: Bool = true

  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    ThemedSection {
      Toggle(isOn: $videoBackgroundPlaybackEnabled) {
        Text("settings_video_background_playback_title".localized)
          .bpFont(.body)
      }
    } footer: {
      Text("settings_video_background_playback_description".localized)
        .bpFont(.caption)
        .foregroundStyle(theme.secondaryColor)
    }
  }
}

#Preview {
  Form {
    VideoPlaybackSectionView()
  }
  .environmentObject(ThemeViewModel())
}
