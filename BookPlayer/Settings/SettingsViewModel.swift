//
//  SettingsViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 30/10/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Foundation

class SettingsViewModel: BaseViewModel<SettingsCoordinator> {
  func toggleFileBackupsPreference(_ flag: Bool) {
    UserDefaults.standard.set(flag, forKey: Constants.UserDefaults.iCloudBackupsEnabled.rawValue)

    // Modify the processed folder to be considered for backups
    var resourceValues = URLResourceValues()
    resourceValues.isExcludedFromBackup = !flag
    var processedFolderURL = DataManager.getProcessedFolderURL()

    try? processedFolderURL.setResourceValues(resourceValues)
  }

  func showPlus() {
    self.coordinator.showPlus()
  }
}
