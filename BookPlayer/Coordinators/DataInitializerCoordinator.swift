//
//  DataInitializerCoordinator.swift
//  BookPlayer
//
//  Created by gianni.carlo on 27/5/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import CoreData
import Foundation

@MainActor
class DataInitializerCoordinator: BPLogger {
  let databaseInitializer: DatabaseInitializer = DatabaseInitializer()
  let alertPresenter: AlertPresenter

  var onFinish: (() -> Void)?

  init(alertPresenter: AlertPresenter) {
    self.alertPresenter = alertPresenter
  }

  public func start() {
    Task {
      await initializeLibrary(isRecoveryAttempt: false)
    }
  }

  func initializeLibrary(isRecoveryAttempt: Bool) async {
    let appDelegate = AppDelegate.shared!
    _ = await appDelegate.setupCoreServicesTask?.result

    if let errorCoreServicesSetup = appDelegate.errorCoreServicesSetup {
      await handleError(errorCoreServicesSetup as NSError)
      return
    }

    await finishLibrarySetup(fromRecovery: isRecoveryAttempt)
  }

  func handleError(_ error: NSError) async {
    if error.domain == NSPOSIXErrorDomain
      && (error.code == ENOSPC
        || error.code == NSFileWriteOutOfSpaceError)
    {
      // CoreData may fail if device doesn't have space
      await MainActor.run {
        alertPresenter.showAlert(
          "error_title".localized,
          message: "coredata_error_diskfull_description".localized,
          completion: nil
        )
      }
    } else if error.code == NSMigrationError || error.code == NSMigrationConstraintViolationError
      || error.code == NSMigrationCancelledError || error.code == NSMigrationMissingSourceModelError
      || error.code == NSMigrationMissingMappingModelError || error.code == NSMigrationManagerSourceStoreError
      || error.code == NSMigrationManagerDestinationStoreError || error.code == NSEntityMigrationPolicyError
      || error.code == NSValidationMultipleErrorsError || error.code == NSValidationMissingMandatoryPropertyError
      || error.code == NSPersistentStoreIncompatibleSchemaError
    {
      Self.logger.warning("Failed to perform migration, attempting recovery with the loading library sequence")
      await MainActor.run {
        alertPresenter.showAlert(
          "error_title".localized,
          message: "coredata_error_migration_description".localized
        ) { [unowned self] in
          recoverLibraryFromFailedMigration()
        }
      }
    } else {
      await MainActor.run {
        let errorDescription = """
          \(error.localizedDescription)

          Error Domain
          \(error.domain) (\(error.code)

          Additional Info
          \(error.userInfo)
          """
        alertPresenter.showAlert(
          BPAlertContent(
            title: "error_title".localized,
            message: errorDescription,
            style: .alert,
            actionItems: [
              BPActionItem(
                title: "ok_button".localized,
                handler: {
                  fatalError("Unresolved error \(error.domain) (\(error.code)): \(error.localizedDescription)")
                }
              ),
              .init(
                title: "Reset and recover database",
                style: .destructive,
                handler: {
                  self.recoverLibraryFromFailedMigration()
                }
              ),
            ]
          )
        )
      }
    }
  }

  func recoverLibraryFromFailedMigration() {
    Task {
      AppDelegate.shared?.resetCoreServices()
      await initializeLibrary(isRecoveryAttempt: true)
    }
  }

  func finishLibrarySetup(fromRecovery: Bool) async {
    let coreServices = AppDelegate.shared!.coreServices!

    setupDefaultState(
      libraryService: coreServices.libraryService,
      dataManager: coreServices.dataManager
    )

    if fromRecovery {
      let files = getLibraryFiles()
      coreServices.libraryService.insertItems(from: files)
    }

    await MainActor.run {
      self.onFinish?()
    }
  }

  private func getLibraryFiles() -> [URL] {
    let enumerator = FileManager.default.enumerator(
      at: DataManager.getProcessedFolderURL(),
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants],
      errorHandler: { (url, error) -> Bool in
        print("directoryEnumerator error at \(url): ", error)
        return true
      }
    )!
    var files = [URL]()
    for case let fileURL as URL in enumerator {
      files.append(fileURL)
    }

    return files
  }

  func setupDefaultState(
    libraryService: LibraryService,
    dataManager: DataManager
  ) {
    let sharedDefaults = UserDefaults.sharedDefaults

    // Migrate user defaults data to shared user defaults
    if sharedDefaults.string(forKey: Constants.UserDefaults.appIcon) == nil {
      let storedIconId = UserDefaults.standard.string(forKey: Constants.UserDefaults.appIcon)
      sharedDefaults.set(storedIconId, forKey: Constants.UserDefaults.appIcon)
    } else if let sharedAppIcon = sharedDefaults.string(forKey: Constants.UserDefaults.appIcon),
      let localAppIcon = UserDefaults.standard.string(forKey: Constants.UserDefaults.appIcon),
      sharedAppIcon != localAppIcon
    {
      sharedDefaults.set(localAppIcon, forKey: Constants.UserDefaults.appIcon)
      UserDefaults.standard.removeObject(forKey: Constants.UserDefaults.appIcon)
    }

    migratePlayerPreferences(sharedDefaults: sharedDefaults)

    // Migrate protection for Processed folder
    if !sharedDefaults.bool(forKey: Constants.UserDefaults.fileProtectionMigration) {
      DataManager.getProcessedFolderURL().disableFileProtection()
      sharedDefaults.set(true, forKey: Constants.UserDefaults.fileProtectionMigration)
    }

    setupUserDefaultsPreferences(sharedDefaults: sharedDefaults)

    setupDefaultTheme(libraryService: libraryService)

    setupBlankAccount(dataManager: dataManager)
  }

  private func migratePlayerPreferences(sharedDefaults: UserDefaults) {
    let chapterContextEnabledKey = Constants.UserDefaults.chapterContextEnabled

    if sharedDefaults.object(forKey: chapterContextEnabledKey) == nil {
      let localPrefersChapterContext = UserDefaults.standard.bool(
        forKey: chapterContextEnabledKey
      )
      sharedDefaults.set(localPrefersChapterContext, forKey: chapterContextEnabledKey)
      UserDefaults.standard.removeObject(forKey: chapterContextEnabledKey)
    }

    let remainingTimeEnabledKey = Constants.UserDefaults.remainingTimeEnabled

    if sharedDefaults.object(forKey: remainingTimeEnabledKey) == nil {
      let localRemainingTimeEnabled = UserDefaults.standard.bool(
        forKey: remainingTimeEnabledKey
      )
      sharedDefaults.set(localRemainingTimeEnabled, forKey: remainingTimeEnabledKey)
      UserDefaults.standard.removeObject(forKey: remainingTimeEnabledKey)
    }
  }

  private func setupUserDefaultsPreferences(sharedDefaults: UserDefaults) {
    // TODO: Look into NSUbiquitousKeyValueStore to persist preferences across devices with iCloud
    let defaults = UserDefaults.standard

    guard !defaults.bool(forKey: Constants.UserDefaults.completedFirstLaunch) else { return }

    // Perform first launch setup

    // Default to include Processed folder in phone backups,
    // when migrating between phones, having the folder excluded have generated issues for users,
    // this can be set to false from within the app settings
    defaults.set(true, forKey: Constants.UserDefaults.iCloudBackupsEnabled)
    var resourceValues = URLResourceValues()
    resourceValues.isExcludedFromBackup = false
    var processedFolderURL = DataManager.getProcessedFolderURL()
    try? processedFolderURL.setResourceValues(resourceValues)

    // Set chapter context as default
    sharedDefaults.set(true, forKey: Constants.UserDefaults.chapterContextEnabled)
    // Set smart-rewind as default
    defaults.set(true, forKey: Constants.UserDefaults.smartRewindEnabled)
    // Set system theme as default
    defaults.set(true, forKey: Constants.UserDefaults.systemThemeVariantEnabled)
    // Set autoplay enabled as default
    defaults.set(true, forKey: Constants.UserDefaults.autoplayEnabled)
    // Set autoplay finished enabled as default
    defaults.set(true, forKey: Constants.UserDefaults.autoplayRestartEnabled)
    // Set remaining time as default
    sharedDefaults.set(true, forKey: Constants.UserDefaults.remainingTimeEnabled)
    // Mark as completed the first launch
    defaults.set(true, forKey: Constants.UserDefaults.completedFirstLaunch)
    // Process install attribution if there's any for the first launch
    BPSKANManager.updateConversionValue(.install)
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
