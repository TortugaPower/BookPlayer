//
//  PlayerManagerProtocol.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 3/10/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

#if os(watchOS)
  import BookPlayerWatchKit
#else
  import BookPlayerKit
#endif
import Combine
import Foundation

/// sourcery: AutoMockable
public protocol PlayerManagerProtocol: AnyObject {
  var currentItem: PlayableItem? { get set }
  var currentSpeed: Float { get set }
  var isPlaying: Bool { get }
  var syncProgressDelegate: PlaybackSyncProgressDelegate? { get set }

  func load(_ item: PlayableItem, autoplay: Bool)
  func hasLoadedBook() -> Bool

  func playPreviousItem()
  func playNextItem(autoPlayed: Bool, shouldAutoplay: Bool)
  func play()
  func playPause()
  func pause()
  func stop()
  func rewind()
  func forward()
  func skip(_ interval: TimeInterval)
  func jumpTo(_ time: Double, recordBookmark: Bool)
  func jumpToChapter(_ chapter: PlayableChapter)
  func markAsCompleted(_ flag: Bool)
  func setSpeed(_ newValue: Float)
  func setBoostVolume(_ newValue: Bool)

  func currentSpeedPublisher() -> AnyPublisher<Float, Never>
  func isPlayingPublisher() -> AnyPublisher<Bool, Never>
  func currentItemPublisher() -> AnyPublisher<PlayableItem?, Never>
}

/// Delegate that hooks into the playback sequence
public protocol PlaybackSyncProgressDelegate: AnyObject {
  func waitForSyncInProgress() async
}
