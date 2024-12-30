//
//  AVPlayer+BookPlayer.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 20/11/20.
//  Copyright © 2020 BookPlayer LLC. All rights reserved.
//

import AVFoundation

extension AVPlayer {
  // Pulled from: https://medium.com/@evandro.hoffmann/fading-volume-with-avplayer-in-swift-74cbcc6172c6
  func fadeVolume(from: Float, to: Float, duration: Float, completion: (() -> Void)? = nil) -> Timer? {
    volume = from

    // skip if target volume is the same as initial
    guard from != to else { return nil }

    let interval: Float = 0.1
    let range = to - from
    let step = (range * interval) / duration

    func reachedTarget() -> Bool {
      guard volume >= 0, volume <= 1 else {
        volume = to
        return true
      }

      if to > from {
        return volume >= to
      }
      return volume <= to
    }

    return Timer.scheduledTimer(withTimeInterval: Double(interval), repeats: true, block: { [weak self] timer in
      guard let self = self else { return }

      DispatchQueue.main.async {
        if !reachedTarget() {
          self.volume += step
        } else {
          timer.invalidate()
          completion?()
        }
      }
    })
  }
}
