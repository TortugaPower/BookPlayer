//
//  PlayerPlatform.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation
import UIKit

/// What the player core needs from the app it runs in: the parts that differ between the phone and the watch,
/// and the ones a Kit framework may not touch, being limited to the API app extensions can use
@MainActor
public protocol PlayerPlatform: AnyObject {
  /// Activates the audio session for a play of `item`. False stops the play
  func activateAudioSession(for item: PlayableItem, origin: PlayOrigin) async -> Bool
  /// Ends the audio session: after a pause, and when a play was dropped while its activation was under way
  func deactivateAudioSession()
  /// Whether folder progress waits until the app is in the foreground again, rather than updating now
  var defersFolderProgress: Bool { get }
  /// The Now Playing artwork for a book without a cover; nil shows none
  func fallbackArtwork() -> UIImage?
  /// Stops listening for the shake that resumes playback after the sleep timer
  func stopShakeDetection()
  /// Calls `handler` on the first shake after the sleep timer paused playback
  func observeFirstShake(_ handler: @escaping () -> Void)
  /// Whether the next book plays on its own when one finishes
  var autoplaysNextBook: Bool { get }
  /// Whether a finished book that autoplay reaches starts over, instead of being skipped
  var restartsFinishedBooks: Bool { get }
}
