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
import UniformTypeIdentifiers

struct DebugFileDocument: FileDocument {
  static var readableContentTypes: [UTType] { [.plainText] }
  let data: Data

  init(data: Data) {
    self.data = data
  }

  init(configuration: ReadConfiguration) throws {
    self.data = configuration.file.regularFileContents ?? Data()
  }

  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: data)
  }
}

struct DebugFileTransferable: Transferable {
  static var transferRepresentation: some TransferRepresentation {
    DataRepresentation(exportedContentType: .text) { file in
      await file.generateDebugData()
    }
    .suggestedFileName { _ in
      return "bookplayer_debug_information.txt"
    }
  }

  let libraryService: LibraryService
  let accountService: AccountService
  let syncService: SyncService

  func generateDebugData() async -> Data {
    var remoteIdentifiers: [String]?
    var syncError: String?

    let syncJobsInformation = await getSyncOperationsInformation()

    if syncService.isActive {
      do {
        remoteIdentifiers = try await syncService.fetchSyncedIdentifiers()
      } catch {
        syncError = "Error fetching remote identifiers: \(error.localizedDescription)"
      }
    }

    let localidentifiers = libraryService.fetchIdentifiers()

    var libraryRepresentation = getLibraryRepresentation(
      localidentifiers: localidentifiers,
      remoteIdentifiers: remoteIdentifiers
    )

    if let remoteIdentifiers,
      let remoteOnlyInfo = getRemoteOnlyInformation(
        localidentifiers: localidentifiers,
        remoteIdentifiers: remoteIdentifiers
      )
    {
      libraryRepresentation += remoteOnlyInfo
    }

    libraryRepresentation += getStorageBreakdown()

    libraryRepresentation += syncJobsInformation

    if let syncError {
      libraryRepresentation += "\n\n⚠️ Sync Error:\n\(syncError)\n"
    }

    return libraryRepresentation.data(using: .utf8)!
  }

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

  func getStorageBreakdown() -> String {
    var info = "\n\n--- Storage Breakdown ---\n"
    let fm = FileManager.default

    let processedURL = DataManager.getProcessedFolderURL()
    let artworkCacheURL = ArtworkService.cacheDirectoryURL
    let backupURL = DataManager.getBackupFolderURL()
    let inboxURL = DataManager.getInboxFolderURL()
    let dbBackupURL = DataManager.getDatabaseBackupFolderURL()
    let syncTasksSwiftDataURL = DataManager.getSyncTasksSwiftDataURL()

    let containerURL = fm.containerURL(
      forSecurityApplicationGroupIdentifier: Constants.ApplicationGroupIdentifier
    )
    let coreDataURL = containerURL?.appendingPathComponent("BookPlayer.sqlite")

    let documentsURL = DataManager.getDocumentsFolderURL()
    let appSupportURL = DataManager.getApplicationSupportFolderURL()
    let cachesURL = fm.urls(for: .cachesDirectory, in: .userDomainMask).first
    let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory())

    // Audiobooks (Processed folder, including hidden files like .dbRealm)
    let processedSize = getFolderSize(processedURL, skipHidden: false)
    let processedVisibleSize = getFolderSize(processedURL, skipHidden: true)
    info += "\nAudiobooks (Processed):       \(formatSize(processedVisibleSize))\n"
    if processedSize != processedVisibleSize {
      info += "  Hidden files in Processed:  \(formatSize(processedSize - processedVisibleSize))\n"
    }

    // Artwork cache
    let artworkSize = getFolderSize(artworkCacheURL, skipHidden: false)
    info += "Artwork cache:                \(formatSize(artworkSize))\n"

    // Backup folder (cloud-deleted files)
    let backupSize = getFolderSize(backupURL, skipHidden: false)
    info += "Backup (cloud-deleted):       \(formatSize(backupSize))\n"

    // Inbox
    let inboxSize = getFolderSize(inboxURL, skipHidden: false)
    info += "Inbox (pending import):       \(formatSize(inboxSize))\n"

    // CoreData
    let coreDataSize = getFileGroupSize(coreDataURL)
    info += "CoreData database:            \(formatSize(coreDataSize))\n"

    // Database backups
    let dbBackupSize = getFolderSize(dbBackupURL, skipHidden: false)
    info += "Database backups:             \(formatSize(dbBackupSize))\n"

    // SwiftData
    let swiftDataSize = getFileGroupSize(syncTasksSwiftDataURL)
    info += "SwiftData (sync tasks):       \(formatSize(swiftDataSize))\n"

    // Caches directory
    var cachesSize: Int64 = 0
    if let cachesURL {
      cachesSize = getFolderSize(cachesURL, skipHidden: false)
      info += "Library/Caches:               \(formatSize(cachesSize))\n"
    }

    // Temp directory
    let tmpSize = getFolderSize(tmpURL, skipHidden: false)
    info += "Temporary files:              \(formatSize(tmpSize))\n"

    // Full container sizes
    info += "\n-- Container Totals --\n"
    let documentsSize = getFolderSize(documentsURL, skipHidden: false)
    info += "Documents folder:             \(formatSize(documentsSize))\n"

    let appSupportSize = getFolderSize(appSupportURL, skipHidden: false)
    info += "Application Support:          \(formatSize(appSupportSize))\n"

    if let containerURL {
      let appGroupSize = getFolderSize(containerURL, skipHidden: false)
      info += "App Group container:          \(formatSize(appGroupSize))\n"
    }

    // What the storage view shows vs total
    let storageViewTotal = processedVisibleSize + artworkSize
    let knownTotal = processedSize + artworkSize + backupSize + inboxSize
      + coreDataSize + dbBackupSize + swiftDataSize + cachesSize + tmpSize
    info += "\nStorage view shows:           \(formatSize(storageViewTotal))\n"
    info += "Known total:                  \(formatSize(knownTotal))\n"

    return info
  }

  /// Get the size of a folder's contents
  private func getFolderSize(_ url: URL, skipHidden: Bool) -> Int64 {
    let fm = FileManager.default
    guard fm.fileExists(atPath: url.path) else { return 0 }

    var options: FileManager.DirectoryEnumerationOptions = []
    if skipHidden {
      options.insert(.skipsHiddenFiles)
    }

    guard let enumerator = fm.enumerator(
      at: url,
      includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
      options: options
    ) else { return 0 }

    var size: Int64 = 0
    for case let fileURL as URL in enumerator {
      guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
            values.isRegularFile == true else { continue }
      size += Int64(values.fileSize ?? 0)
    }
    return size
  }

  /// Get the size of a sqlite file and its associated -wal and -shm files
  private func getFileGroupSize(_ url: URL?) -> Int64 {
    guard let url else { return 0 }
    let fm = FileManager.default
    var size: Int64 = 0
    for suffix in ["", "-wal", "-shm"] {
      let fileURL = URL(fileURLWithPath: url.path + suffix)
      if let attrs = try? fm.attributesOfItem(atPath: fileURL.path),
         let fileSize = attrs[.size] as? Int64 {
        size += fileSize
      }
    }
    return size
  }

  private func formatSize(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
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
      information += "Uuid: \(lastError.uuid)\n"
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
      information += "  Uuid: \(job.uuid)\n"
      information += "  Parameters:\n"
      for (key, value) in job.parameters.sorted(by: { $0.key < $1.key }) {
        // Skip id, relativePath and uuid as they're already shown
        if key == "id" || key == "relativePath" || key == "uuid" { continue }
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
