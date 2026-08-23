//
//  ExternalUpdateProgressOperation.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 23/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

class ExternalUpdateProgressOperation: AsyncOperation, @unchecked Sendable {

  let providerName: String
  let providerItemId: String
  let positionTicks: Int
  let percentCompleted: Double
  let hostId: String?

  init(providerName: String, providerItemId: String, positionTicks: Int, percentCompleted: Double, hostId: String? = nil) {
    self.providerName = providerName
    self.providerItemId = providerItemId
    self.positionTicks = positionTicks
    self.percentCompleted = percentCompleted
    self.hostId = hostId
    super.init()
  }

  override func main() {
    guard !isCancelled else {
      self.finish()
      return
    }

    Task {
      // 1. defer guarantees this runs at the very end of the Task's scope,
      // even if a crash or a throw happens inside.
      defer {
        self.finish()
      }
      try await Task.sleep(for: .seconds(5))
      // 2. Wrap the throwing code in a do-catch
      do {

        switch ExternalResource.ProviderName(rawValue: self.providerName) {
        case .jellyfin:
          try await doJellyfinUpdate()
        case .audiobookshelf:
          try await doAudiobookshelfUpdate()
        default:
          break
        }

        // If the code reaches here, the network request succeeded!
        self.didSucceed = true

      } catch {
        // If it throws, execution instantly jumps here.
        print("🔴 OPERATION FAILED WITH ERROR: \(error)")
        self.didSucceed = false
      }
    }
  }

  func doJellyfinUpdate() async throws {
    let jellyfinService = JellyfinConnectionService()
    await jellyfinService.setup()

    // Stable-host resolution only. An unresolvable host means this device doesn't have the
    // server the resource belongs to — pushing to whichever connection is active would write
    // progress to the WRONG server, so the update is deliberately dropped. Dropping means
    // CONSUMING the task (didSucceed = true): the queue only pops successful tasks and retries
    // failures forever, and an unknown host is a permanent condition on this device — leaving
    // it failed would retry every few seconds until the end of time (same discard semantics as
    // the Android app's external-update task).
    guard let targetConnection = await IntegrationHostResolver.connection(
      for: self.hostId, in: jellyfinService.connections
    ) else {
      self.didSucceed = true
      return
    }
    await jellyfinService.useConnection(targetConnection)

    try await jellyfinService.updateItemProgress(
      self.providerItemId,
      positionTicks: self.positionTicks,
      percentCompleted: self.percentCompleted
    )
  }

  func doAudiobookshelfUpdate() async throws {
    let audiobookshelfService = AudiobookShelfConnectionService()
    await audiobookshelfService.setup()

    // Same stable-host discard-by-consuming semantics as the Jellyfin path above.
    guard let targetConnection = await IntegrationHostResolver.connection(
      for: self.hostId, in: audiobookshelfService.connections
    ) else {
      self.didSucceed = true
      return
    }
    await audiobookshelfService.useConnection(targetConnection)

    try await audiobookshelfService.updateProgress(for: self.providerItemId, progress: self.percentCompleted, currentTime: Double(self.positionTicks / 10_000_000))
  }
}
