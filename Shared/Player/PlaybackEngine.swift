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

/// What happens to an item the engine loads
enum LoadEvent {
  /// It can play
  case ready
  /// It can't, with the reason the engine gives
  case failed(Error?)
  /// Playback reached its end
  case ended
}

/// An item the engine loaded. Its events reach the caller until this is cancelled or let go; the item
/// stays in the player until the next load or `unload()`
final class EngineLoad {
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

#if os(iOS)
/// App-owned group coordination. The engine exposes only AVFoundation's coordinator, not
/// its player; GroupActivities and the activity's content identity stay in the iOS app.
@MainActor
public protocol PlaybackCoordinating: AnyObject {
  /// Captures this item's content identity on main before AVFoundation may ask for it off main.
  func prepareForPlayback(of playerItem: AVPlayerItem?)
  func coordinate(_ coordinator: AVPlayerPlaybackCoordinator)
  func stopCoordinating(_ coordinator: AVPlayerPlaybackCoordinator)
  /// Restores the audio session when the group resumes without a local play command.
  func activateAudioSession()
}
#endif

/// Drives playback of one item at a time. `PlayerManager` talks only to this: only an
/// implementation and the video surfaces touch `AVPlayer`.
@MainActor
protocol PlaybackEngine: AnyObject {
  #if os(iOS)
  /// Held across rebuilds, and detached when cleared or replaced.
  var playbackCoordination: PlaybackCoordinating? { get set }
  /// Refreshes the identity after book metadata changes without replacing the player item.
  func refreshPlaybackCoordination()
  #endif
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
  /// The item in the player failed after it was ready, as a stream can mid-playback: the next play loads it again
  var itemHasFailed: Bool { get }
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
  /// Puts `asset` in the player, replacing its item. `events` runs on the main queue, never before this
  /// returns: `.ready` or `.failed` once (an item already ready still reports), then `.ended` when playback
  /// reaches its end
  func load(_ asset: AVURLAsset, events: @escaping (LoadEvent) -> Void) -> EngineLoad
  /// Empties the player
  func unload()
  /// A new player after a media-services reset or a failed one. Observers move over and the
  /// status publisher stays; the item doesn't
  func rebuild()
}
