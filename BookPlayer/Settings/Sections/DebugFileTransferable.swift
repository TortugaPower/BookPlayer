//
//  DebugFileTransferable.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 21/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct DebugFileTransferable: Transferable {
  static var transferRepresentation: some TransferRepresentation {
    DataRepresentation(exportedContentType: .text) { file in
      let syncService = file.syncService
      let libraryService = file.libraryService

      var remoteIdentifiers: [String]?
      var syncJobsInformation: String?
      var syncError: String?

      if syncService.isActive {
        do {
          remoteIdentifiers = try await syncService.fetchSyncedIdentifiers()
        } catch {
          syncError = "Error fetching remote identifiers: \(error.localizedDescription)"
        }
        syncJobsInformation = await file.getSyncOperationsInformation()
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
    var information = ""

    if let syncEmail = accountService.getAccount()?.email {
      information += "\n\nProfile: \(syncEmail)\n"
    }

    let jobs = await syncService.getAllQueuedJobs()

    information += "Queued jobs count: \(jobs.count)\n"

    for job in jobs {
      information += "[\(job.jobType.rawValue)] \(job.relativePath)\n"
    }

    return information
  }
}
