//
//  BackgroundSessionWakeCoordinator+Live.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation
import UIKit

extension BackgroundSessionWakeCoordinator.Dependencies {
  /// The phone's: settles under a UIKit background task, for up to 25 s
  @MainActor
  static var live: Self {
    Self(
      activateSessions: { identifier in
        if BackgroundTransferSessions.uploadIdentifiers.contains(identifier) {
          BackgroundTransferSessions.activateUploadSessions()
        }
      },
      settleUploads: {
        guard let queue = try? await AppServices.shared.awaitCoreServices().syncQueueService else { return }
        await queue.settleUploads()
      },
      settleDownloads: {
        guard let sync = try? await AppServices.shared.awaitCoreServices().syncService else { return }
        await sync.settleDownloads()
      },
      beginBackgroundTime: { expiration in
        let task = UIApplication.shared.beginBackgroundTask(
          withName: "background-session-wake",
          expirationHandler: expiration
        )
        guard task != .invalid else { return nil }

        return { UIApplication.shared.endBackgroundTask(task) }
      },
      timeout: .seconds(25)
    )
  }
}
