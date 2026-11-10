//
//  PlayerTestDoubles.swift
//  BookPlayerTests
//
//  Created by Gianni Carlo on 11/8/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import AVFoundation
import Foundation

@testable import BookPlayer

/// `AVPlayer` that never touches AVFoundation's playback pipeline: items are held without loading,
/// and play, pause, the clock, seeks, the periodic tick and boundary crossings are all driven by the test.
final class ControlledPlayer: AVPlayer {
  // MARK: Items

  /// Every item handed to `replaceCurrentItem(with:)`, `nil` included, in order
  private(set) var replacedItems: [AVPlayerItem?] = []
  private var heldItem: AVPlayerItem?

  override var currentItem: AVPlayerItem? { heldItem }

  override func replaceCurrentItem(with item: AVPlayerItem?) {
    replacedItems.append(item)
    heldItem = item
  }

  // MARK: Play and pause

  /// The rate of every `playImmediately(atRate:)` call, in order
  private(set) var playCalls: [Float] = []
  private(set) var pauseCalls = 0
  private var heldRate: Float = 0
  private var heldTimeControlStatus: AVPlayer.TimeControlStatus = .paused

  override var rate: Float {
    get { heldRate }
    set { heldRate = newValue }
  }

  override var timeControlStatus: AVPlayer.TimeControlStatus { heldTimeControlStatus }

  override func playImmediately(atRate rate: Float) {
    playCalls.append(rate)
    heldRate = rate
    setTimeControlStatus(.playing)
    /// As AVPlayer does, seen in the app: playback starting exactly on a boundary crosses it
    runBoundaries(at: reportedTime)
  }

  override func play() {
    playImmediately(atRate: 1)
  }

  override func pause() {
    pauseCalls += 1
    heldRate = 0
    setTimeControlStatus(.paused)
  }

  /// `PlayerManager` follows the status through a KVO publisher
  private func setTimeControlStatus(_ status: AVPlayer.TimeControlStatus) {
    guard status != heldTimeControlStatus else { return }

    willChangeValue(forKey: "timeControlStatus")
    heldTimeControlStatus = status
    didChangeValue(forKey: "timeControlStatus")
  }

  // MARK: Clock and seeks

  /// What `currentTime()` reports
  var reportedTime: TimeInterval = 0
  /// Off: a seek waits for `finishSeek`, still reporting the position it left
  var landsSeeksImmediately = true
  private(set) var seekTargets: [TimeInterval] = []
  /// The seeks asked to land exactly on their target, a subset of `seekTargets`
  private(set) var preciseSeekTargets: [TimeInterval] = []
  private var pendingSeeks: [(target: TimeInterval, completion: (Bool) -> Void)] = []

  override func currentTime() -> CMTime {
    CMTime(seconds: reportedTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
  }

  override func seek(to time: CMTime) {
    seek(to: time) { _ in }
  }

  override func seek(to time: CMTime, completionHandler: @escaping @Sendable (Bool) -> Void) {
    seekTargets.append(time.seconds)
    guard landsSeeksImmediately else {
      pendingSeeks.append((time.seconds, completionHandler))
      return
    }

    reportedTime = time.seconds
    completionHandler(true)
  }

  override func seek(
    to time: CMTime,
    toleranceBefore: CMTime,
    toleranceAfter: CMTime,
    completionHandler: @escaping @Sendable (Bool) -> Void
  ) {
    if toleranceBefore == .zero, toleranceAfter == .zero {
      preciseSeekTargets.append(time.seconds)
    }
    seek(to: time, completionHandler: completionHandler)
  }

  /// Completes the oldest pending seek, moving the clock if it wasn't interrupted
  func finishSeek(finished: Bool = true) {
    guard !pendingSeeks.isEmpty else { return }

    let seek = pendingSeeks.removeFirst()
    if finished {
      reportedTime = seek.target
    }
    seek.completion(finished)
  }

  // MARK: Time observers

  private var tick: (token: NSObject, block: (CMTime) -> Void)?
  private var boundaries: [(token: NSObject, times: [TimeInterval], block: () -> Void)] = []

  override func addPeriodicTimeObserver(
    forInterval interval: CMTime,
    queue: DispatchQueue?,
    using block: @escaping @Sendable (CMTime) -> Void
  ) -> Any {
    let token = NSObject()
    tick = (token, block)
    return token
  }

  override func addBoundaryTimeObserver(
    forTimes times: [NSValue],
    queue: DispatchQueue?,
    using block: @escaping @Sendable () -> Void
  ) -> Any {
    let token = NSObject()
    boundaries.append((token, times.map { $0.timeValue.seconds }, block))
    return token
  }

  /// Removals of observers this player never added, which raise in production: a rebuild that loses
  /// track of which player holds an observer
  private(set) var unknownTimeObserverRemovals = 0

  override func removeTimeObserver(_ observer: Any) {
    let token = observer as AnyObject
    if tick?.token === token {
      tick = nil
    } else if boundaries.contains(where: { $0.token === token }) {
      boundaries.removeAll { $0.token === token }
    } else {
      unknownTimeObserverRemovals += 1
    }
  }

  var hasTickObserver: Bool { tick != nil }

  /// Every boundary time observed, in order
  var boundaryTimes: [TimeInterval] { boundaries.flatMap(\.times).sorted() }

  /// Runs the periodic observer once, as the 1 s tick would, at `reportedTime`
  func fireTick() {
    tick?.block(currentTime())
  }

  /// Plays across `time`, as playback reaching it would, and runs the boundary observers there
  func crossBoundary(at time: TimeInterval) {
    reportedTime = time
    runBoundaries(at: time)
  }

  /// Times go through a nanosecond `CMTime` on the way in, so they're matched to the nanosecond
  private func runBoundaries(at time: TimeInterval) {
    for boundary in boundaries where boundary.times.contains(where: { abs($0 - time) < 1e-9 }) {
      boundary.block()
    }
  }
}

/// `AVPlayerItem` whose status the test sets, and which counts `PlayerManager`'s `status` observers.
///
/// A remove without a matching add is what raises "Cannot remove an observer … for the key path
/// "status"" in production. Here it is counted in `unbalancedRemoves` instead, so the crash family
/// fails an assertion rather than crashing the test run.
final class ControlledPlayerItem: AVPlayerItem {
  private var heldStatus: AVPlayerItem.Status = .unknown
  private var heldError: Error?

  override var status: AVPlayerItem.Status { heldStatus }
  override var error: Error? { heldError }

  /// Moves the status, notifying KVO observers as AVFoundation would
  func become(_ status: AVPlayerItem.Status, error: Error? = nil) {
    willChangeValue(forKey: "status")
    heldStatus = status
    heldError = error
    didChangeValue(forKey: "status")
  }

  private(set) var statusObserverAdds = 0
  private(set) var statusObserverRemoves = 0
  private(set) var unbalancedRemoves = 0

  var isStatusObserved: Bool { statusObserverAdds > statusObserverRemoves }

  override func addObserver(
    _ observer: NSObject,
    forKeyPath keyPath: String,
    options: NSKeyValueObservingOptions = [],
    context: UnsafeMutableRawPointer?
  ) {
    if keyPath == "status", observer is PlayerManager {
      statusObserverAdds += 1
    }
    super.addObserver(observer, forKeyPath: keyPath, options: options, context: context)
  }

  override func removeObserver(_ observer: NSObject, forKeyPath keyPath: String) {
    if keyPath == "status", observer is PlayerManager {
      guard isStatusObserved else {
        unbalancedRemoves += 1
        return
      }
      statusObserverRemoves += 1
    }
    super.removeObserver(observer, forKeyPath: keyPath)
  }
}
