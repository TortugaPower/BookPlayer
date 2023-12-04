//
//  SettingsViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 30/10/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation

class SettingsViewModel: ViewModelProtocol {
  /// Available routes
  enum Routes {
    case pro
    case themes
    case icons
    case playerControls
    case storageManagement
    case deletedFilesManagement
    case tipJar
    case credits
    case debugFiles(libraryRepresentation: String)
  }

  enum Events {
    case showLoader(flag: Bool)
    case showAlert(content: BPAlertContent)
  }

  weak var coordinator: SettingsCoordinator!
  let accountService: AccountServiceProtocol
  let libraryService: LibraryServiceProtocol
  let syncService: SyncServiceProtocol

  var onTransition: BPTransition<Routes>?

  @Published var account: Account?

  private var disposeBag = Set<AnyCancellable>()
  var eventsPublisher = InterfaceUpdater<SettingsViewModel.Events>()

  init(
    accountService: AccountServiceProtocol,
    libraryService: LibraryServiceProtocol,
    syncService: SyncServiceProtocol
  ) {
    self.accountService = accountService
    self.libraryService = libraryService
    self.syncService = syncService
    self.reloadAccount()
    self.bindObservers()
  }

  func bindObservers() {
    NotificationCenter.default.publisher(for: .accountUpdate, object: nil)
      .sink(receiveValue: { [weak self] _ in
        self?.reloadAccount()
      })
      .store(in: &disposeBag)
  }

  func observeEvents() -> AnyPublisher<SettingsViewModel.Events, Never> {
    eventsPublisher.eraseToAnyPublisher()
  }

  private func sendEvent(_ event: SettingsViewModel.Events) {
    eventsPublisher.send(event)
  }

  func reloadAccount() {
    self.account = self.accountService.getAccount()
  }

  func hasMadeDonation() -> Bool {
    return account?.hasSubscription == true
  }

  func toggleFileBackupsPreference(_ flag: Bool) {
    UserDefaults.standard.set(flag, forKey: Constants.UserDefaults.iCloudBackupsEnabled)

    // Modify the processed folder to be considered for backups
    var resourceValues = URLResourceValues()
    resourceValues.isExcludedFromBackup = !flag
    var processedFolderURL = DataManager.getProcessedFolderURL()

    try? processedFolderURL.setResourceValues(resourceValues)
  }

  /// Handle registering the value in `UserDefaults`
  func toggleCrashReportsAccess(_ flag: Bool) {
    UserDefaults.standard.set(flag, forKey: Constants.UserDefaults.crashReportsDisabled)
  }

  /// Handle registering the value in `UserDefaults`
  func toggleSKANPreference(_ flag: Bool) {
    UserDefaults.standard.set(flag, forKey: Constants.UserDefaults.skanAttributionDisabled)
  }

  func showPro() {
    onTransition?(.pro)
  }

  func showTipJar() {
    onTransition?(.tipJar)
  }

  func showStorageManagement() {
    onTransition?(.storageManagement)
  }

  func showCloudDeletedFiles() {
    onTransition?(.deletedFilesManagement)
  }

  func showThemes() {
    onTransition?(.themes)
  }

  func showIcons() {
    onTransition?(.icons)
  }

  func showPlayerControls() {
    onTransition?(.playerControls)
  }

  func showCredits() {
    onTransition?(.credits)
  }

  func shareDebugFiles() {
    sendEvent(.showLoader(flag: true))

    Task { @MainActor in
      do {
        var remoteIdentifiers: [String]?

        if syncService.isActive {
          remoteIdentifiers = try await syncService.fetchSyncedIdentifiers()
        }

        let localidentifiers = libraryService.fetchIdentifiers()

        let libraryRepresentation = getLibraryRepresentation(
          localidentifiers: localidentifiers,
          remoteIdentifiers: remoteIdentifiers
        )

        sendEvent(.showLoader(flag: false))
        onTransition?(.debugFiles(libraryRepresentation: libraryRepresentation))
      } catch {
        sendEvent(.showLoader(flag: false))
        sendEvent(.showAlert(
          content: BPAlertContent.errorAlert(message: error.localizedDescription)
        ))
      }
    }
  }

  /// Get a representation of the library like with the `tree` command
  /// Note:  For the first status, '✓' means the backing file exists, and '𐄂' that it's missing locally,
  /// and for the second status, ☐ means the file is not uploaded yet, and ☑ that it's already synced
  func getLibraryRepresentation(
    localidentifiers: [String],
    remoteIdentifiers: [String]?
  ) -> String {
    let identifiers = libraryService.fetchIdentifiers()

    var libraryRepresentation = ".\n"
    let processedFolderURL = DataManager.getProcessedFolderURL()

    let baseSeparator = "|   "
    var nestedLevel = 0

    for (index, identifier) in identifiers.enumerated() {
      let fileURL = processedFolderURL.appendingPathComponent(identifier)
      let fileExistsRepresentation = getFileExistsRepresentation(
        identifier: identifier,
        fileURL: fileURL,
        remoteIdentifiers: remoteIdentifiers
      )
      let isLast = index == (identifiers.endIndex - 1)
      let newNestedLevel = identifier.components(separatedBy: "/").count - 1
      var horizontalSeparator = String(repeating: baseSeparator, count: newNestedLevel)

      if nestedLevel != newNestedLevel || isLast || fileURL.isDirectoryFolder {
        horizontalSeparator += horizontalSeparator + "`-- "
      } else {
        horizontalSeparator += horizontalSeparator +  "|-- "
      }

      libraryRepresentation += "\(horizontalSeparator)\(fileExistsRepresentation) \(fileURL.lastPathComponent)\n"

      nestedLevel = newNestedLevel
    }

    return libraryRepresentation
  }

  func getFileExistsRepresentation(
    identifier: String,
    fileURL: URL,
    remoteIdentifiers: [String]?
  ) -> String {
    let localRepresentation = FileManager.default.fileExists(atPath: fileURL.path)
    ? "[✓]"
    : "[𐄂]"

    guard let remoteIdentifiers else {
      return localRepresentation
    }

    if remoteIdentifiers.contains(identifier) {
      return localRepresentation + "[☑]"
    } else {
      return localRepresentation + "[☐]"
    }
  }
}
