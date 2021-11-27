//
//  LoadingViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 26/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import CoreData
import Foundation

class LoadingViewModel: BaseViewModel<LoadingCoordinator> {
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

    stack.loadStore { [weak self] _, error in
      if let error = error {
        self?.handleCoreDataError(error)
        return
      }

      let dataManager = DataManager(coreDataStack: stack)

      self?.setupDefaultState(dataManager: dataManager)

      self?.coordinator.didFinishLoadingSequence(coreDataStack: stack)
    }
  }

  func handleCoreDataError(_ error: Error) {
    let error = error as NSError
    // CoreData may fail if device doesn't have space
    if (error.domain == NSPOSIXErrorDomain && error.code == ENOSPC) ||
        (error.domain == NSCocoaErrorDomain && error.code == NSFileWriteOutOfSpaceError) {
      self.coordinator.showAlert("error_title".localized, message: "coredata_error_diskfull_description".localized)
      return
    }

    // Handle data error migration by reloading library
    if error.code == NSMigrationError ||
        error.code == NSMigrationConstraintViolationError ||
        error.code == NSMigrationCancelledError ||
        error.code == NSMigrationMissingSourceModelError ||
        error.code == NSMigrationMissingMappingModelError ||
        error.code == NSMigrationManagerSourceStoreError ||
        error.code == NSMigrationManagerDestinationStoreError ||
        error.code == NSEntityMigrationPolicyError {
      self.coordinator.showAlert("error_title".localized, message: "coredata_error_migration_description".localized) {
        self.dataMigrationManager.cleanupStoreFile()
        let urls = self.getLibraryFiles()
        self.reloadLibrary(with: urls)
      }
      return
    }

    fatalError("Unresolved error \(error), \(error.userInfo)")
  }

  func getLibraryFiles() -> [URL] {
    let enumerator = FileManager.default.enumerator(
      at: DataManager.getProcessedFolderURL(),
      includingPropertiesForKeys: [.creationDateKey, .isDirectoryKey],
      options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants], errorHandler: { (url, error) -> Bool in
        print("directoryEnumerator error at \(url): ", error)
        return true
      })!
    var files = [URL]()
    for case let fileURL as URL in enumerator {
      files.append(fileURL)
    }

    return files
  }

  func reloadLibrary(with files: [URL]) {
    let stack = self.dataMigrationManager.getCoreDataStack()
    stack.loadStore { [weak self] _, error in
      if let error = error {
        self?.handleCoreDataError(error)
        return
      }

      let dataManager = DataManager(coreDataStack: stack)

      self?.setupDefaultState(dataManager: dataManager)

      let libraryService = LibraryService(dataManager: dataManager)

      let library = libraryService.getLibrary()

      _ = libraryService.insertItems(from: files, into: nil, library: library, processedItems: [])

      self?.coordinator.didFinishLoadingSequence(coreDataStack: stack)
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

    // Default to include Processed folder in phone backups,
    // when migrating between phones, having the folder excluded have generated issues for users,
    // this can be set to false from within the app settings
    if UserDefaults.standard.object(forKey: Constants.UserDefaults.iCloudBackupsEnabled.rawValue) == nil {
      UserDefaults.standard.set(true, forKey: Constants.UserDefaults.iCloudBackupsEnabled.rawValue)

      var resourceValues = URLResourceValues()
      resourceValues.isExcludedFromBackup = false
      var processedFolderURL = DataManager.getProcessedFolderURL()

      try? processedFolderURL.setResourceValues(resourceValues)
    }

    // Set system theme as default
    if UserDefaults.standard.object(forKey: Constants.UserDefaults.systemThemeVariantEnabled.rawValue) == nil {
      UserDefaults.standard.set(true, forKey: Constants.UserDefaults.systemThemeVariantEnabled.rawValue)
    }

    let libraryService = LibraryService(dataManager: dataManager)

    // Load themes into DB if necessary
    self.loadLocalThemesIfNeeded(libraryService)

    // Load default theme into library if needed
    let library = libraryService.getLibrary()

    if library.currentTheme == nil {
      libraryService.setLibraryTheme(with: "Default / Dark")
    }
  }

  public func loadLocalThemesIfNeeded(_ libraryService: LibraryService) {
    guard
      libraryService.getTheme(with: "Default / Dark") == nil,
      let themesFile = Bundle.main.url(forResource: "Themes", withExtension: "json"),
      let data = try? Data(contentsOf: themesFile, options: .mappedIfSafe),
      let jsonObject = try? JSONSerialization.jsonObject(with: data, options: .mutableLeaves),
      let themeParams = jsonObject as? [[String: Any]]
    else { return }

    themeParams.forEach({ _ = libraryService.createTheme(params: $0) })
  }
}
