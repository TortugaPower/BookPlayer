//
//  AVPlayerEngine.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import AVFoundation
import Combine
import Foundation

/// The `PlaybackEngine` on `AVPlayer`
final class AVPlayerEngine: PlaybackEngine {
  /// Makes the player on every (re)build. Injected so tests drive a player that never loads media
  private let makePlayer: () -> AVPlayer
  private var player: AVPlayer
  private let statusSubject = CurrentValueSubject<EngineStatus, Never>(.paused)
  private var statusSubscription: AnyCancellable?

  /// What callers registered, so a rebuild can add it to the new player
  private struct PeriodicObserver {
    let interval: TimeInterval
    let block: @Sendable () -> Void
    var token: Any
  }
  private var periodicObservers: [UUID: PeriodicObserver] = [:]

  init(makePlayer: @escaping () -> AVPlayer = { AVPlayer() }) {
    self.makePlayer = makePlayer
    self.player = makePlayer()
    configure(player)
  }

  var statusPublisher: AnyPublisher<EngineStatus, Never> {
    statusSubject.eraseToAnyPublisher()
  }

  var status: EngineStatus {
    Self.status(of: player.timeControlStatus)
  }

  var rate: Float {
    get { player.rate }
    set { player.rate = newValue }
  }

  var currentTime: TimeInterval {
    CMTimeGetSeconds(player.currentTime())
  }

  var volume: Float {
    get { player.volume }
    set { player.volume = newValue }
  }

  var isMuted: Bool {
    get { player.isMuted }
    set { player.isMuted = newValue }
  }

  var hasFailed: Bool {
    player.status == .failed
  }

  var videoPlayer: AVPlayer? {
    player
  }

  func play(atRate rate: Float) {
    player.playImmediately(atRate: rate)
  }

  func pause() {
    player.pause()
  }

  func seek(to time: TimeInterval, completion: @escaping @Sendable (Bool) -> Void) {
    player.seek(to: CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC)), completionHandler: completion)
  }

  func addPeriodicObserver(every interval: TimeInterval, _ block: @escaping @Sendable () -> Void) -> EngineObservation {
    let id = UUID()
    periodicObservers[id] = PeriodicObserver(
      interval: interval,
      block: block,
      token: addPeriodicTimeObserver(to: player, every: interval, block)
    )

    return EngineObservation { [weak self] in
      guard let self, let observer = self.periodicObservers.removeValue(forKey: id) else { return }
      self.player.removeTimeObserver(observer.token)
    }
  }

  func fadeVolume(from: Float, to: Float, duration: Float) -> Timer? {
    player.fadeVolume(from: from, to: to, duration: duration)
  }

  func replaceItem(_ item: AVPlayerItem?) {
    player.replaceCurrentItem(with: item)
  }

  func rebuild() {
    for observer in periodicObservers.values {
      player.removeTimeObserver(observer.token)
    }

    player = makePlayer()
    configure(player)

    for (id, observer) in periodicObservers {
      periodicObservers[id]?.token = addPeriodicTimeObserver(to: player, every: observer.interval, observer.block)
    }
  }

  private func configure(_ player: AVPlayer) {
    // Only route audio for AirPlay
    player.allowsExternalPlayback = false

    statusSubscription = player.publisher(for: \.timeControlStatus)
      .sink { [weak self] timeControlStatus in
        self?.statusSubject.send(Self.status(of: timeControlStatus))
      }
  }

  private func addPeriodicTimeObserver(
    to player: AVPlayer,
    every interval: TimeInterval,
    _ block: @escaping @Sendable () -> Void
  ) -> Any {
    player.addPeriodicTimeObserver(
      forInterval: CMTime(seconds: interval, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
      queue: DispatchQueue.main
    ) { _ in
      block()
    }
  }

  private static func status(of timeControlStatus: AVPlayer.TimeControlStatus) -> EngineStatus {
    switch timeControlStatus {
    case .playing:
      return .playing
    case .waitingToPlayAtSpecifiedRate:
      return .waiting
    case .paused:
      return .paused
    @unknown default:
      return .paused
    }
  }
}
