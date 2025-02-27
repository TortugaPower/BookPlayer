//
//  ListSyncRefreshService.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 30/1/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation

enum BPSyncRefreshError: Error {
  /// There are queued tasks and can't fetch remote data
  case scheduledTasks
  case disabled
}

class ListSyncRefreshService: BPLogger {
  let playerManager: PlayerManagerProtocol
  let syncService: SyncServiceProtocol

  init(
    playerManager: PlayerManagerProtocol,
    syncService: SyncServiceProtocol
  ) {
    self.playerManager = playerManager
    self.syncService = syncService
  }

  func syncList(at relativePath: String?, alertPresenter: AlertPresenter) async {
    do {
      if let relativePath {
        try await syncService.syncListContents(at: relativePath)
      } else if UserDefaults.standard.bool(forKey: Constants.UserDefaults.hasScheduledLibraryContents) == true {
        try await syncService.syncListContents(at: nil)
      } else {
        try await syncService.syncLibraryContents()
      }
    } catch BPSyncError.reloadLastBook(let relativePath) {
      await reloadLastBook(relativePath: relativePath, alertPresenter: alertPresenter)
    } catch BPSyncError.differentLastBook(let relativePath) {
      await setSyncedLastPlayedItem(relativePath: relativePath, alertPresenter: alertPresenter)
    } catch {
      Self.logger.trace("Sync contents error: \(error.localizedDescription)")
    }
  }

  @MainActor
  private func reloadLastBook(relativePath: String, alertPresenter: AlertPresenter) {
    let wasPlaying = playerManager.isPlaying
    playerManager.stop()

    Task { @MainActor in
      do {
        try await AppDelegate.shared?.coreServices?.playerLoaderService.loadPlayer(
          relativePath,
          autoplay: wasPlaying
        )
      } catch BPPlayerError.fileMissing {
        alertPresenter.showAlert(
          "file_missing_title".localized,
          message:
            "\("file_missing_description".localized)\n\(relativePath)",
          completion: nil
        )
      } catch {
        alertPresenter.showAlert(
          "error_title".localized,
          message: error.localizedDescription,
          completion: nil
        )
      }
    }
  }

  @MainActor
  private func setSyncedLastPlayedItem(relativePath: String, alertPresenter: AlertPresenter) async {
    /// Only continue overriding local book if it's not currently playing
    guard playerManager.isPlaying == false else { return }

    await syncService.setLibraryLastBook(with: relativePath)

    do {
      try await AppDelegate.shared?.coreServices?.playerLoaderService.loadPlayer(
        relativePath,
        autoplay: false
      )
    } catch BPPlayerError.fileMissing {
      alertPresenter.showAlert(
        "file_missing_title".localized,
        message:
          "\("file_missing_description".localized)\n\(relativePath)",
        completion: nil
      )
    } catch {
      alertPresenter.showAlert(
        "error_title".localized,
        message: error.localizedDescription,
        completion: nil
      )
    }
  }
}
