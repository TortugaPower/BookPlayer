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
  private struct TimeObserver {
    enum Kind {
      case periodic(TimeInterval, @Sendable () -> Void)
      /// One per time, so the block knows which one was crossed
      case boundary(TimeInterval, @Sendable (TimeInterval) -> Void)
    }

    let kind: Kind
    var token: Any
  }
  private var timeObservers: [UUID: TimeObserver] = [:]

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

  func seek(to time: TimeInterval, precisely: Bool, completion: @escaping @Sendable (Bool) -> Void) {
    let target = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))

    if precisely {
      player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero, completionHandler: completion)
    } else {
      player.seek(to: target, completionHandler: completion)
    }
  }

  func addPeriodicObserver(every interval: TimeInterval, _ block: @escaping @Sendable () -> Void) -> EngineObservation {
    observe([.periodic(interval, block)])
  }

  func addBoundaryObserver(
    at times: [TimeInterval],
    _ block: @escaping @Sendable (TimeInterval) -> Void
  ) -> EngineObservation {
    observe(times.map { .boundary($0, block) })
  }

  func fadeVolume(from: Float, to: Float, duration: Float) -> Timer? {
    player.fadeVolume(from: from, to: to, duration: duration)
  }

  func replaceItem(_ item: AVPlayerItem?) {
    player.replaceCurrentItem(with: item)
  }

  func rebuild() {
    for observer in timeObservers.values {
      player.removeTimeObserver(observer.token)
    }

    player = makePlayer()
    configure(player)

    for (id, observer) in timeObservers {
      timeObservers[id]?.token = add(observer.kind, to: player)
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

  /// Registers `kinds` on the current player, behind one token that removes them all
  private func observe(_ kinds: [TimeObserver.Kind]) -> EngineObservation {
    let ids = kinds.map { kind in
      let id = UUID()
      timeObservers[id] = TimeObserver(kind: kind, token: add(kind, to: player))
      return id
    }

    return EngineObservation { [weak self] in
      guard let self else { return }

      for id in ids {
        guard let observer = self.timeObservers.removeValue(forKey: id) else { continue }
        self.player.removeTimeObserver(observer.token)
      }
    }
  }

  private func add(_ kind: TimeObserver.Kind, to player: AVPlayer) -> Any {
    switch kind {
    case .periodic(let interval, let block):
      return player.addPeriodicTimeObserver(forInterval: Self.cmTime(interval), queue: DispatchQueue.main) { _ in
        block()
      }
    case .boundary(let time, let block):
      return player.addBoundaryTimeObserver(forTimes: [NSValue(time: Self.cmTime(time))], queue: DispatchQueue.main) {
        block(time)
      }
    }
  }

  private static func cmTime(_ seconds: TimeInterval) -> CMTime {
    CMTime(seconds: seconds, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
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
