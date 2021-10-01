//
//  LoadingViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 26/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Foundation

class LoadingViewModel {
  var coordinator: LoadingCoordinator!
  let dataMigrationManager: DataMigrationManager

  init(dataMigrationManager: DataMigrationManager) {
    self.dataMigrationManager = dataMigrationManager
  }

  func performMigrations() {
    if self.dataMigrationManager.canPeformMigration() {
      self.handleMigrations()
    } else {
      self.loadLibrary()
    }
  }

  private func handleMigrations() {
    guard self.dataMigrationManager.needsMigration() else {
      self.loadLibrary()
      return
    }

    do {
      try self.dataMigrationManager.performMigration { [weak self] error in
        if let error = error {
          self?.coordinator.showAlert("error_title".localized, message: error.localizedDescription)
          return
        }

        self?.handleMigrations()
      }
    } catch {
      self.coordinator.showAlert("error_title".localized, message: error.localizedDescription)
    }
  }

  func loadLibrary() {
    let stack = self.dataMigrationManager.getCoreDataStack()

    stack.loadStore { _, error in
      print("=== error: \(error)")

      let dataManager = DataManager(coreDataStack: stack)

      self.setupDefaultState(dataManager: dataManager)

      self.coordinator.didFinishLoadingSequence(coreDataStack: stack)
    }
  }

  func setupDefaultState(dataManager: DataManager) {
    let userDefaults = UserDefaults(suiteName: Constants.ApplicationGroupIdentifier)

    // Migrate user defaults app icon
    if userDefaults?
        .string(forKey: Constants.UserDefaults.appIcon.rawValue) == nil {
      let storedIconId = UserDefaults.standard.string(forKey: Constants.UserDefaults.appIcon.rawValue)
      userDefaults?.set(storedIconId, forKey: Constants.UserDefaults.appIcon.rawValue)
    } else if let sharedAppIcon = userDefaults?
                .string(forKey: Constants.UserDefaults.appIcon.rawValue),
              let localAppIcon = UserDefaults.standard.string(forKey: Constants.UserDefaults.appIcon.rawValue),
              sharedAppIcon != localAppIcon {
      userDefaults?.set(localAppIcon, forKey: Constants.UserDefaults.appIcon.rawValue)
      UserDefaults.standard.removeObject(forKey: Constants.UserDefaults.appIcon.rawValue)
    }

    // Migrate protection for Processed folder
    if !(userDefaults?
          .bool(forKey: Constants.UserDefaults.fileProtectionMigration.rawValue) ?? false) {
      DataManager.getProcessedFolderURL().disableFileProtection()
      userDefaults?.set(true, forKey: Constants.UserDefaults.fileProtectionMigration.rawValue)
    }

    // Exclude Processed folder from phone backups
    var resourceValues = URLResourceValues()
    resourceValues.isExcludedFromBackup = true
    var processedFolderURL = DataManager.getProcessedFolderURL()

    try? processedFolderURL.setResourceValues(resourceValues)

    // Set system theme as default
    if UserDefaults.standard.object(forKey: Constants.UserDefaults.systemThemeVariantEnabled.rawValue) == nil {
      UserDefaults.standard.set(true, forKey: Constants.UserDefaults.systemThemeVariantEnabled.rawValue)
    }

    // Load themes into DB if necessary
    if !dataManager.hasThemesLoaded() {
      dataManager.loadLocalThemes()
    }
  }
}
