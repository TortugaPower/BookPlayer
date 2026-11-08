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
/// and play, pause, the clock, seeks and the periodic tick are all driven by the test.
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

  /// Completes the oldest pending seek, moving the clock if it wasn't interrupted
  func finishSeek(finished: Bool = true) {
    guard !pendingSeeks.isEmpty else { return }

    let seek = pendingSeeks.removeFirst()
    if finished {
      reportedTime = seek.target
    }
    seek.completion(finished)
  }

  // MARK: Periodic tick

  private var tick: ((CMTime) -> Void)?
  private(set) var removedTimeObservers = 0

  override func addPeriodicTimeObserver(
    forInterval interval: CMTime,
    queue: DispatchQueue?,
    using block: @escaping @Sendable (CMTime) -> Void
  ) -> Any {
    tick = block
    return NSObject()
  }

  override func removeTimeObserver(_ observer: Any) {
    removedTimeObservers += 1
    tick = nil
  }

  /// Runs the periodic observer once, as the 1 s tick would, at `reportedTime`
  func fireTick() {
    tick?(currentTime())
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
