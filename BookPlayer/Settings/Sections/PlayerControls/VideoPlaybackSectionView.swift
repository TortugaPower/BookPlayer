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
  @AppStorage(Constants.UserDefaults.videoPictureInPictureEnabled)
  var videoPictureInPictureEnabled: Bool = false

  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    ThemedSection {
      Toggle(isOn: $videoPictureInPictureEnabled) {
        Text("settings_video_pip_title".localized)
          .bpFont(.body)
      }
    } footer: {
      Text("settings_video_pip_description".localized)
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
