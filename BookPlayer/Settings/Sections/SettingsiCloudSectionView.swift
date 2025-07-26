//
//  SettingsiCloudSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 19/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct SettingsiCloudSectionView: View {
  @AppStorage(Constants.UserDefaults.iCloudBackupsEnabled)
  var isEnabled: Bool = true
  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    Section {
      Toggle("settings_backup_files_title", isOn: $isEnabled)
    } header: {
      Text("settings_backup_title")
        .foregroundStyle(theme.secondaryColor)
    }
  }
}

#Preview {
  NavigationStack {
    Form {
      SettingsiCloudSectionView()
    }
  }
  .environmentObject(ThemeViewModel())
}
