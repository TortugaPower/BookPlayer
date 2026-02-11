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
    ThemedSection {
      NavigationLink(value: SettingsScreen.storage) {
        Text("settings_storage_description")
          .bpFont(.body)
      }
      if accessLevel == .pro {
        NavigationLink(value: SettingsScreen.syncbackup) {
          Text("settings_storage_sync_deleted_description")
            .bpFont(.body)
        }
      }
    } header: {
      Text("settings_storage_title")
        .bpFont(.subheadline)
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
