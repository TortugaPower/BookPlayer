//
//  DataInitializerCoordinator.swift
//  BookPlayer
//
//  Created by gianni.carlo on 27/5/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import CoreData
import Foundation

class DataInitializerCoordinator: BPLogger {
  let dataMigrationManager: DataMigrationManager
  let alertPresenter: AlertPresenter

  var onFinish: ((CoreDataStack) -> Void)?

  init(
    dataMigrationManager: DataMigrationManager = DataMigrationManager(),
    alertPresenter: AlertPresenter
  ) {
    self.dataMigrationManager = dataMigrationManager
    self.alertPresenter = alertPresenter
  }

  public func start() {
    self.performMigrations()
  }

  private func performMigrations() {
    if self.dataMigrationManager.canPeformMigration() {
      self.handleMigrations()
    } else {
      self.loadLibrary()
    }
  }

  private func handleMigrations() {
    guard dataMigrationManager.needsMigration() else {
      loadLibrary()
      return
    }

    do {
      try dataMigrationManager.performMigration {
        self.handleMigrations()
      }
    } catch {
      Self.logger.info("Failed to perform migration")
      loadLibrary()
    }
  }

  func loadLibrary() {
    Self.logger.info("Loading store")
    let stack = self.dataMigrationManager.getCoreDataStack()

    stack.loadStore { [weak self] _, error in
      if let error = error {
        Self.logger.error("Failed to load store")
        self?.handleCoreDataError(error)
        return
      }

      let dataManager = DataManager(coreDataStack: stack)
      let libraryService = LibraryService(dataManager: dataManager)
      _ = libraryService.getLibrary()

      self?.setupDefaultState(
        libraryService: libraryService,
        dataManager: dataManager
      )

      self?.onFinish?(stack)
    }
  }

  func handleCoreDataError(_ error: Error) {
    let error = error as NSError
    // CoreData may fail if device doesn't have space
    if (error.domain == NSPOSIXErrorDomain && error.code == ENOSPC) ||
        (error.domain == NSCocoaErrorDomain && error.code == NSFileWriteOutOfSpaceError) {
      self.alertPresenter.showAlert("error_title".localized, message: "coredata_error_diskfull_description".localized, completion: nil)
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
        error.code == NSEntityMigrationPolicyError ||
        error.code == NSValidationMultipleErrorsError ||
        error.code == NSValidationMissingMandatoryPropertyError {
      self.alertPresenter.showAlert("error_title".localized, message: "coredata_error_migration_description".localized) {
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

      let libraryService = LibraryService(dataManager: dataManager)

      /// Create library on disk
      _ = libraryService.getLibrary()

      self?.setupDefaultState(
        libraryService: libraryService,
        dataManager: dataManager
      )

      libraryService.insertItems(from: files)

      self?.onFinish?(stack)
    }
  }

  func setupDefaultState(
    libraryService: LibraryService,
    dataManager: DataManager
  ) {
    let userDefaults = UserDefaults(suiteName: Constants.ApplicationGroupIdentifier)

    // Migrate user defaults app icon
    if userDefaults?
        .string(forKey: Constants.UserDefaults.appIcon) == nil {
      let storedIconId = UserDefaults.standard.string(forKey: Constants.UserDefaults.appIcon)
      userDefaults?.set(storedIconId, forKey: Constants.UserDefaults.appIcon)
    } else if let sharedAppIcon = userDefaults?
                .string(forKey: Constants.UserDefaults.appIcon),
              let localAppIcon = UserDefaults.standard.string(forKey: Constants.UserDefaults.appIcon),
              sharedAppIcon != localAppIcon {
      userDefaults?.set(localAppIcon, forKey: Constants.UserDefaults.appIcon)
      UserDefaults.standard.removeObject(forKey: Constants.UserDefaults.appIcon)
    }

    // Migrate protection for Processed folder
    if !(userDefaults?
          .bool(forKey: Constants.UserDefaults.fileProtectionMigration) ?? false) {
      DataManager.getProcessedFolderURL().disableFileProtection()
      userDefaults?.set(true, forKey: Constants.UserDefaults.fileProtectionMigration)
    }

    // Default to include Processed folder in phone backups,
    // when migrating between phones, having the folder excluded have generated issues for users,
    // this can be set to false from within the app settings
    if UserDefaults.standard.object(forKey: Constants.UserDefaults.iCloudBackupsEnabled) == nil {
      UserDefaults.standard.set(true, forKey: Constants.UserDefaults.iCloudBackupsEnabled)

      var resourceValues = URLResourceValues()
      resourceValues.isExcludedFromBackup = false
      var processedFolderURL = DataManager.getProcessedFolderURL()

      try? processedFolderURL.setResourceValues(resourceValues)
    }

    // Set system theme as default
    if UserDefaults.standard.object(forKey: Constants.UserDefaults.systemThemeVariantEnabled) == nil {
      UserDefaults.standard.set(true, forKey: Constants.UserDefaults.systemThemeVariantEnabled)
    }
    // Set autoplay enabled as default
    if UserDefaults.standard.object(forKey: Constants.UserDefaults.autoplayEnabled) == nil {
      UserDefaults.standard.set(true, forKey: Constants.UserDefaults.autoplayEnabled)
    }
    // Set autoplay finished enabled as default
    if UserDefaults.standard.object(forKey: Constants.UserDefaults.autoplayRestartEnabled) == nil {
      UserDefaults.standard.set(true, forKey: Constants.UserDefaults.autoplayRestartEnabled)
    }
    // Set remaining time as default
    if UserDefaults.standard.object(forKey: Constants.UserDefaults.remainingTimeEnabled) == nil {
      UserDefaults.standard.set(true, forKey: Constants.UserDefaults.remainingTimeEnabled)
    }

    setupDefaultTheme(libraryService: libraryService)

    setupBlankAccount(dataManager: dataManager)
  }

  func setupDefaultTheme(libraryService: LibraryService) {
    guard libraryService.getLibraryCurrentTheme() == nil else { return }

    libraryService.setLibraryTheme(
      with: SimpleTheme.getDefaultTheme()
    )
  }

  /// Setup blank account for donationMade key migration
  func setupBlankAccount(dataManager: DataManager) {
    let accountService = AccountService(dataManager: dataManager)

    guard !accountService.hasAccount() else { return }

    accountService.createAccount(
      donationMade: UserDefaults.standard.bool(forKey: Constants.UserDefaults.donationMade)
    )

    UserDefaults.standard.set(nil, forKey: Constants.UserDefaults.donationMade)
  }
}
