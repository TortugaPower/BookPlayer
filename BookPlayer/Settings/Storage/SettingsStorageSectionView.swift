//
//  SettingsStorageSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 19/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct SettingsStorageSectionView: View {
  var accessLevel: AccessLevel
  @EnvironmentObject var theme: ThemeViewModel
  
  var body: some View {
    Section {
      NavigationLink("settings_storage_description", value: SettingsScreen.storage)
      if accessLevel == .pro {
        NavigationLink("settings_storage_sync_deleted_description", value: SettingsScreen.syncbackup)
      }
    } header: {
      Text("settings_storage_title")
        .foregroundStyle(theme.secondaryColor)
    }
  }
}

#Preview {
  @Previewable var accessLevel: AccessLevel = .pro
  NavigationStack {
    Form {
      SettingsStorageSectionView(accessLevel: accessLevel)
    }
  }
  .environmentObject(ThemeViewModel())
}
