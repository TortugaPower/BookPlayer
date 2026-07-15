//
//  StartupPlayerSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 27/6/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct StartupPlayerSectionView: View {
  @AppStorage(Constants.UserDefaults.openPlayerOnAppLaunch) var openPlayerOnAppLaunch: Bool = false
  @AppStorage(Constants.UserDefaults.carPlayShowPlayerOnConnect) var carPlayShowPlayerOnConnect: Bool = false

  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    ThemedSection {
      Toggle(isOn: $openPlayerOnAppLaunch) {
        Text("settings_openplayer_launch_title")
          .bpFont(.body)
      }
      Toggle(isOn: $carPlayShowPlayerOnConnect) {
        Text("settings_carplay_showplayer_title")
          .bpFont(.body)
      }
    } footer: {
      Text("settings_startupplayer_description")
        .bpFont(.caption)
        .foregroundStyle(theme.secondaryColor)
    }
  }
}

#Preview {
  Form {
    StartupPlayerSectionView()
  }
  .environmentObject(ThemeViewModel())
}
