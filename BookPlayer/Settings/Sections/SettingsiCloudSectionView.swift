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

  @Environment(\.loadingState) private var loadingState
  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    Section {
      Toggle(
        isOn: Binding(
          get: { isEnabled },
          set: { newValue in
            isEnabled = handleUpdate(newValue)
          }
        )
      ) {
        Text("settings_backup_files_title")
          .bpFont(.body)
      }
    } header: {
      Text("settings_backup_title")
        .bpFont(.subheadline)
        .foregroundStyle(theme.secondaryColor)
    }
    .listRowBackground(theme.tertiarySystemBackgroundColor)
  }

  func handleUpdate(_ flag: Bool) -> Bool {
    var resourceValues = URLResourceValues()
    resourceValues.isExcludedFromBackup = !flag
    var processedFolderURL = DataManager.getProcessedFolderURL()

    do {
      try processedFolderURL.setResourceValues(resourceValues)
      return flag
    } catch {
      loadingState.error = error
      return !flag
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
