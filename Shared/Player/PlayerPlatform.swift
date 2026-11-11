//
//  PlayerPlatform.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation
import UIKit

/// What the player core needs from the app it runs in: the parts that differ by platform, and the ones a
/// Kit framework may not touch, being limited to the API app extensions can use
@MainActor
public protocol PlayerPlatform: AnyObject {
  /// Activates the audio session for a play of `item`. False stops the play
  func activateAudioSession(for item: PlayableItem, origin: PlayOrigin) async -> Bool
  /// Whether folder progress waits until the app is in the foreground again, rather than updating now
  var defersFolderProgress: Bool { get }
  /// The colour of the Now Playing artwork drawn for a book without a cover; nil draws none
  var fallbackArtworkColor: UIColor? { get }
  /// Stops listening for the shake that resumes playback after the sleep timer
  func stopShakeDetection()
  /// Calls `handler` on the first shake after the sleep timer paused playback
  func observeFirstShake(_ handler: @escaping () -> Void)
}
