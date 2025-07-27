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

  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    Section {
      Toggle("settings_smartrewind_title", isOn: $smartRewindEnabled)
        .tint(theme.linkColor)
    } footer: {
      Text("settings_smartrewind_description")
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
