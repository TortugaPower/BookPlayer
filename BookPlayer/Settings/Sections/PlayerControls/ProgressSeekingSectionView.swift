//
//  ProgressSeekingSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 27/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import MediaPlayer
import SwiftUI

struct ProgressSeekingSectionView: View {
  @AppStorage(Constants.UserDefaults.seekProgressBarEnabled) var seekEnabled: Bool = true

  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    ThemedSection {
      Toggle(isOn: $seekEnabled) {
        Text("settings_seekprogressbar_title")
          .bpFont(.body)
      }
      .onChange(of: seekEnabled) {
        MPRemoteCommandCenter.shared().changePlaybackPositionCommand.isEnabled = seekEnabled
      }
    } footer: {
      Text("settings_seekprogressbar_description")
        .bpFont(.caption)
        .foregroundStyle(theme.secondaryColor)
    }
  }
}

#Preview {
  Form {
    ProgressSeekingSectionView()
  }
  .environmentObject(ThemeViewModel())
}
