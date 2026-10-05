//
//  PlayerTimeSample.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/10/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

/// What a position reported by the player means, judged against the last position we trust.
///
/// iOS 27 on the CarPlay route can move playback to the start of the file while reporting a time
/// 2^32 samples behind the real one (a large negative), then snap the paused item to exactly 0.
/// Neither is where the listener is, so neither may be recorded (GH #1605).
enum PlayerTimeSample: Equatable {
  /// A real position: record it
  case valid(TimeInterval)
  /// Not a position, but playback is where we left it: drop it
  case ignore
  /// The player moved without us: drop it and seek back to the last trusted position
  case recover

  /// How far into the current file a reading at or before its start stops being plausible
  private static let negativeTimeRecoveryThreshold: TimeInterval = 3
  private static let fileStartRecoveryThreshold: TimeInterval = 30

  /// - Parameters:
  ///   - playerTime: The time the player reports, relative to the current file
  ///   - expected: The last position we trust in the same file, if there is one
  init(playerTime: TimeInterval, expected: TimeInterval?) {
    let expected = expected ?? 0

    guard playerTime.isFinite, playerTime >= 0 else {
      /// A small negative right at a file start is output latency (AirPlay, bound-book chapter switches)
      self = expected > Self.negativeTimeRecoveryThreshold ? .recover : .ignore
      return
    }

    /// Back at the file start while well into it, without a seek of ours putting it there.
    /// The threshold leaves room for Picture in Picture's skip-back, which seeks the player directly
    if playerTime < 0.5, expected > Self.fileStartRecoveryThreshold {
      self = .recover
      return
    }

    self = .valid(playerTime)
  }
}
