//
//  JellyfinUpdateProgressOperation.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 23/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

class JellyfinUpdateProgressOperation: AsyncOperation, @unchecked Sendable {
  
  let providerItemId: String
  let positionTicks: Int
  let percentCompleted: Double
  
  let jellyfinService: JellyfinConnectionService
  
  init(providerItemId: String, positionTicks: Int, percentCompleted: Double, service: JellyfinConnectionService) {
    self.providerItemId = providerItemId
    self.positionTicks = positionTicks
    self.percentCompleted = percentCompleted
    self.jellyfinService = service
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
            
      // 2. Wrap the throwing code in a do-catch
      do {
        try await jellyfinService.updateItemProgress(
          self.providerItemId,
          positionTicks: self.positionTicks,
          percentCompleted: self.percentCompleted
        )
        
        // If the code reaches here, the network request succeeded!
        self.didSucceed = true
        
      } catch {
        // If it throws, execution instantly jumps here.
        print("🔴 OPERATION FAILED WITH ERROR: \(error)")
        self.didSucceed = false
      }
    }
  }
}
