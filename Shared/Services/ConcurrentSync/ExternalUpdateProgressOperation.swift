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
    
  init(providerName: String, providerItemId: String, positionTicks: Int, percentCompleted: Double) {
    self.providerName = providerName
    self.providerItemId = providerItemId
    self.positionTicks = positionTicks
    self.percentCompleted = percentCompleted
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
    jellyfinService.setup()
    
    try await jellyfinService.updateItemProgress(
      self.providerItemId,
      positionTicks: self.positionTicks,
      percentCompleted: self.percentCompleted
    )
  }
  
  func doAudiobookshelfUpdate() async throws {
    let audiobookshelfService = AudiobookShelfConnectionService()
    audiobookshelfService.setup()
    
    try await audiobookshelfService.updateProgress(for: self.providerItemId, progress: self.percentCompleted, currentTime: Double(self.positionTicks / 10_000_000))
  }
}
