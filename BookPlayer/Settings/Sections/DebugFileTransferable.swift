//
//  DebugFileTransferable.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 21/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import RevenueCat
import SwiftUI

struct DebugFileTransferable: Transferable {
  static var transferRepresentation: some TransferRepresentation {
    DataRepresentation(exportedContentType: .text) { file in
      let syncService = file.syncService
      let libraryService = file.libraryService

      var remoteIdentifiers: [String]?
      var syncJobsInformation: String?
      var syncError: String?

      // Always get sync state information regardless of isActive
      syncJobsInformation = await file.getSyncOperationsInformation()

      if syncService.isActive {
        do {
          remoteIdentifiers = try await syncService.fetchSyncedIdentifiers()
        } catch {
          syncError = "Error fetching remote identifiers: \(error.localizedDescription)"
        }
      }

      let localidentifiers = libraryService.fetchIdentifiers()

      var libraryRepresentation = file.getLibraryRepresentation(
        localidentifiers: localidentifiers,
        remoteIdentifiers: remoteIdentifiers
      )

      if let remoteIdentifiers,
        let remoteOnlyInfo = file.getRemoteOnlyInformation(
          localidentifiers: localidentifiers,
          remoteIdentifiers: remoteIdentifiers
        )
      {
        libraryRepresentation += remoteOnlyInfo
      }

      if let syncJobsInformation {
        libraryRepresentation += syncJobsInformation
      }

      if let syncError {
        libraryRepresentation += "\n\n⚠️ Sync Error:\n\(syncError)\n"
      }

      return libraryRepresentation.data(using: .utf8)!
    }
    .suggestedFileName { _ in
      return "bookplayer_debug_information.txt"
    }
  }

  let libraryService: LibraryService
  let accountService: AccountService
  let syncService: SyncService

  /// Get a representation of the library like with the `tree` command
  /// Note:  For the first status, '✓' means the backing file exists, and '𐄂' that it's missing locally,
  /// and for the second status, ☐ means the file is not uploaded yet, and ☑ that it's already synced
  func getLibraryRepresentation(
    localidentifiers: [String],
    remoteIdentifiers: [String]?
  ) -> String {
    let identifiers = libraryService.fetchIdentifiers()

    var libraryRepresentation = "Library\n.\n"
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
        horizontalSeparator += horizontalSeparator + "|-- "
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
    let localRepresentation =
      FileManager.default.fileExists(atPath: fileURL.path)
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

  func getRemoteOnlyInformation(
    localidentifiers: [String],
    remoteIdentifiers: [String]
  ) -> String? {
    var remoteOnlyIdentifiers = Array(Set(remoteIdentifiers).subtracting(Set(localidentifiers)))

    guard !remoteOnlyIdentifiers.isEmpty else {
      return nil
    }

    remoteOnlyIdentifiers.sort(by: { $0.localizedStandardCompare($1) == ComparisonResult.orderedAscending })

    var remoteInfo = "\n\nRemote only items:\n"

    for remoteOnlyIdentifier in remoteOnlyIdentifiers {
      remoteInfo += "\(remoteOnlyIdentifier)\n"
    }

    return remoteInfo
  }

  func getSyncOperationsInformation() async -> String {
    var information = "\n\n--- Sync Debug Information ---\n"

    // Account information
    if let account = accountService.getAccount() {
      information += "\nProfile: \(account.email)\n"
      information += "Account ID: \(account.id)\n"
    } else {
      information += "\nProfile: Not logged in\n"
    }

    // RevenueCat information
    information += getRevenueCatInformation()

    // Sync state
    information += "\n-- Sync State --\n"
    information += "Sync isActive: \(syncService.isActive)\n"
    information += "Has account: \(accountService.hasAccount())\n"
    information += "RevenueCat sync enabled: \(accountService.hasSyncEnabled())\n"

    // Auth token status
    let keychain = KeychainService()
    let hasToken = (try? keychain.get(.token) as String?) != nil
    information += "Auth token present: \(hasToken ? "Yes" : "No")\n"

    // Last sync timestamps
    information += getLastSyncTimestamps()

    // Last sync error
    if let lastError = syncService.getLastSyncError() {
      information += "\n-- Last Sync Error --\n"
      information += "Task ID: \(lastError.taskId)\n"
      information += "Path: \(lastError.relativePath)\n"
      information += "Job Type: \(lastError.jobType.rawValue)\n"
      information += "Error: \(lastError.error)\n"
      information += "Timestamp: \(lastError.timestamp)\n"
    }

    // Queued jobs with parameters
    let jobs = await syncService.getAllQueuedJobsWithParams()

    information += "\n-- Queued Jobs (\(jobs.count)) --\n"

    for (index, job) in jobs.enumerated() {
      information += "\n[\(index + 1)] \(job.jobType.rawValue)\n"
      information += "  Task ID: \(job.id)\n"
      information += "  Path: \(job.relativePath)\n"
      information += "  Parameters:\n"
      for (key, value) in job.parameters.sorted(by: { $0.key < $1.key }) {
        // Skip id and relativePath as they're already shown
        if key == "id" || key == "relativePath" { continue }
        information += "    \(key): \(value)\n"
      }
    }

    return information
  }

  private func getRevenueCatInformation() -> String {
    var info = "\n-- RevenueCat Info --\n"

    guard let customerInfo = Purchases.shared.cachedCustomerInfo else {
      info += "Customer info: Not available\n"
      return info
    }

    info += "Original App User ID: \(customerInfo.originalAppUserId)\n"

    // Check if current ID is different (indicates logged in state)
    if customerInfo.originalAppUserId != Purchases.shared.appUserID {
      info += "Current App User ID: \(Purchases.shared.appUserID)\n"
    }

    // Pro entitlement status
    if let proEntitlement = customerInfo.entitlements["pro"] {
      info += "Pro entitlement active: \(proEntitlement.isActive)\n"
      if let expirationDate = proEntitlement.expirationDate {
        info += "Pro expiration: \(expirationDate)\n"
      }
    } else {
      info += "Pro entitlement: Not found\n"
    }

    return info
  }

  private func getLastSyncTimestamps() -> String {
    var info = "\n-- Last Sync Timestamps --\n"

    let libraryKey = "\(Constants.UserDefaults.lastSyncTimestamp)_library"
    let lastLibrarySync = UserDefaults.standard.double(forKey: libraryKey)

    if lastLibrarySync > 0 {
      let date = Date(timeIntervalSince1970: lastLibrarySync)
      info += "Library: \(date)\n"
    } else {
      info += "Library: Never\n"
    }

    let hasScheduledContents = UserDefaults.standard.bool(
      forKey: Constants.UserDefaults.hasScheduledLibraryContents
    )
    info += "Has scheduled library contents: \(hasScheduledContents)\n"

    return info
  }
}
