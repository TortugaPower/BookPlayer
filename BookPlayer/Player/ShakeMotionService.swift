//
//  ShakeMotionService.swift
//  BookPlayer
//
//  Created by gianni.carlo on 17/7/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import CoreMotion
import Foundation

/// sourcery: AutoMockable
protocol ShakeMotionServiceProtocol {
  func observeFirstShake(completion: @escaping () -> Void)
  func stopMotionUpdates()
}

class ShakeMotionService: ShakeMotionServiceProtocol {
  /// Reference to cleanup task
  private var timeoutWorkItem: DispatchWorkItem?
  /// Manager to start monitoring motions
  private lazy var manager: CMMotionManager = {
    let manager = CMMotionManager()
    manager.deviceMotionUpdateInterval = 0.02
    return manager
  }()
  /// Start observing motion updates for 1 minute, and call the completion callback when a shake motion is detected
  func observeFirstShake(completion: @escaping () -> Void) {
    var xInPositiveDirection = 0.0
    var xInNegativeDirection = 0.0
    var shakeCount = 0

    timeoutWorkItem?.cancel()
    let workItem = DispatchWorkItem { [weak self] in
      self?.stopMotionUpdates()
    }
    timeoutWorkItem = workItem

    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(60), execute: workItem)

    /// Taken from: https://stackoverflow.com/a/55264779
    manager.startDeviceMotionUpdates(to: OperationQueue.main, withHandler: { [weak self] (data, _) in
      guard
        let data,
        data.userAcceleration.x > 1.0 || data.userAcceleration.x < -1.0
      else { return }

      if data.userAcceleration.x > 1.0 {
        xInPositiveDirection = data.userAcceleration.x
      }

      if data.userAcceleration.x < -1.0 {
        xInNegativeDirection = data.userAcceleration.x
      }

      if xInPositiveDirection != 0.0 && xInNegativeDirection != 0.0 {
        shakeCount += 1
        xInPositiveDirection = 0.0
        xInNegativeDirection = 0.0
      }

      if shakeCount > 1 {
        self?.timeoutWorkItem?.cancel()
        self?.stopMotionUpdates()
        completion()
      }
    })
  }

  /// Stop monitoring motion updates
  func stopMotionUpdates() {
    manager.stopDeviceMotionUpdates()
  }
}
