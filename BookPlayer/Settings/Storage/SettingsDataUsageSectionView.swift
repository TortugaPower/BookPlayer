//
//  SettingsDataUsageSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 19/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct SettingsDataUsageSectionView: View {
  @AppStorage(Constants.UserDefaults.allowCellularData)
  var isEnabled: Bool = false
  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    Section {
      Toggle(isOn: $isEnabled) {
        Text("datausage_upload_wifionly_title")
          .bpFont(.body)
      }
    } header: {
      Text("settings_datausage_title")
        .bpFont(.subheadline)
        .foregroundStyle(theme.secondaryColor)
    }
  }
}

#Preview {
  NavigationStack {
    Form {
      SettingsDataUsageSectionView()
    }
  }
  .environmentObject(ThemeViewModel())
}
