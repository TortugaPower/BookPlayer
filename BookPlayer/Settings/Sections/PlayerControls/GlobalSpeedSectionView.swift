//
//  GlobalSpeedSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 27/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct GlobalSpeedSectionView: View {
  @AppStorage(Constants.UserDefaults.globalSpeedEnabled) var globalSpeedEnabled: Bool = false

  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    Section {
      Toggle("settings_globalspeed_title", isOn: $globalSpeedEnabled)
        .tint(theme.linkColor)
    } footer: {
      Text("settings_globalspeed_description")
        .foregroundStyle(theme.secondaryColor)
    }
  }
}

#Preview {
  Form {
    GlobalSpeedSectionView()
  }
  .environmentObject(ThemeViewModel())
}
