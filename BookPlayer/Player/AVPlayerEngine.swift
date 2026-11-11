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
@MainActor
final class AVPlayerEngine: PlaybackEngine {
  /// Makes the player on every (re)build. Injected so tests drive a player that never loads media
  private let makePlayer: () -> AVPlayer
  /// Wraps an asset in the item put in the player. Injected so tests control its status
  private let makePlayerItem: (AVURLAsset) -> AVPlayerItem
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

  init(
    makePlayer: @escaping () -> AVPlayer = { AVPlayer() },
    makePlayerItem: @escaping (AVURLAsset) -> AVPlayerItem = { AVPlayerItem(asset: $0) }
  ) {
    self.makePlayer = makePlayer
    self.makePlayerItem = makePlayerItem
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

  var itemHasFailed: Bool {
    guard let item = player.currentItem else { return false }

    return item.status == .failed || item.error != nil
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

  func load(_ asset: AVURLAsset, events: @escaping (LoadEvent) -> Void) -> EngineLoad {
    let item = makePlayerItem(asset)
    item.audioTimePitchAlgorithm = .timeDomain

    let observers = ItemObservers(observing: item, events: events)
    player.replaceCurrentItem(with: item)

    return EngineLoad { observers.stop() }
  }

  func unload() {
    player.replaceCurrentItem(with: nil)
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

/// The observers of one loaded item: its status until it's ready or failed, and its end. Its
/// `EngineLoad` stops them
@MainActor
private final class ItemObservers {
  private let events: (LoadEvent) -> Void
  private var status: AnyCancellable?
  private var end: AnyCancellable?
  /// Set when its load is cancelled: an event already on its way to main is dropped
  private var isStopped = false

  init(observing item: AVPlayerItem, events: @escaping (LoadEvent) -> Void) {
    self.events = events

    /// `.initial`, so an item that's ready before it's observed still reports. Each value hops to main,
    /// even from main: AVFoundation doesn't promise main, and no event may reach the caller before
    /// `load` returns
    status = item.publisher(for: \.status, options: [.initial, .new])
      .receive(on: DispatchQueue.main)
      .sink { [weak self, weak item] status in
        self?.statusChanged(to: status, error: item?.error)
      }

    /// For this item only: another player's item ending, or this player's previous one, isn't ours
    end = NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: item)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        guard let self, !self.isStopped else { return }

        self.events(.ended)
      }
  }

  func stop() {
    isStopped = true
    status = nil
    end = nil
  }

  /// Reports once, when the item is ready or failed: a value queued behind that one finds the status no
  /// longer observed
  private func statusChanged(to newStatus: AVPlayerItem.Status, error: Error?) {
    guard !isStopped, status != nil else { return }

    switch newStatus {
    case .readyToPlay:
      status = nil
      events(.ready)
    case .failed:
      status = nil
      events(.failed(error))
    case .unknown:
      break
    @unknown default:
      break
    }
  }
}
