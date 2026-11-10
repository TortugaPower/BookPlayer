//
//  PlaybackEngine.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import AVFoundation
import Combine
import Foundation

/// Whether the engine is producing audio
enum EngineStatus: Equatable {
  case paused
  /// Asked to play, and waiting for data
  case waiting
  case playing
}

/// A time observer an engine holds. Cancelling it, or letting it go, removes it
final class EngineObservation {
  private var onCancel: (() -> Void)?

  init(onCancel: @escaping () -> Void) {
    self.onCancel = onCancel
  }

  func cancel() {
    onCancel?()
    onCancel = nil
  }

  deinit {
    cancel()
  }
}

/// Drives playback of one item at a time. `PlayerManager` talks only to this: only an
/// implementation and the video surfaces touch `AVPlayer`.
protocol PlaybackEngine: AnyObject {
  /// The same publisher for the engine's whole life, across rebuilds
  var statusPublisher: AnyPublisher<EngineStatus, Never> { get }
  var status: EngineStatus { get }
  /// The engine's rate, 0 when paused. The user's speed stays in `PlayerManager`
  var rate: Float { get set }
  /// Seconds into the current item, as the player reports it
  var currentTime: TimeInterval { get }
  var volume: Float { get set }
  var isMuted: Bool { get set }
  /// The player itself failed: `rebuild()` replaces it
  var hasFailed: Bool { get }
  /// For video artwork and Picture in Picture only; nil for an engine without one
  var videoPlayer: AVPlayer? { get }

  func play(atRate rate: Float)
  func pause()
  /// `precisely` lands on `time` itself instead of wherever is quickest nearby
  func seek(to time: TimeInterval, precisely: Bool, completion: @escaping @Sendable (Bool) -> Void)
  /// Calls `block` on the main queue every `interval` of playback. Kept across rebuilds
  func addPeriodicObserver(every interval: TimeInterval, _ block: @escaping @Sendable () -> Void) -> EngineObservation
  /// Calls `block` on the main queue with the time playback crosses, for each of `times` in the current
  /// item. Seeks don't cross. Kept across rebuilds
  func addBoundaryObserver(
    at times: [TimeInterval],
    _ block: @escaping @Sendable (TimeInterval) -> Void
  ) -> EngineObservation
  func fadeVolume(from: Float, to: Float, duration: Float) -> Timer?
  /// Until `ItemLoad` (rework PR 5) moves item creation behind the engine as `load(_ source:)`
  func replaceItem(_ item: AVPlayerItem?)
  /// A new player after a media-services reset or a failed one. Observers move over and the
  /// status publisher stays; the item doesn't
  func rebuild()
}
