//
//  SharePlayPlaybackCoordination.swift
//  BookPlayer
//
//  Created by dawsonamf on 6/28/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import AVFoundation
import BookPlayerKit
import Foundation

/// Holds the session and its content identity in the app, not in either shared Kit.
@MainActor
final class SharePlayPlaybackCoordination: NSObject, PlaybackCoordinating, AVPlayerPlaybackCoordinatorDelegate, BPLogger {
  private let contentIdentifier: String
  /// The local item matched to the session's book; coordination is scoped to it so
  /// other content never reports the session's identity
  private let relativePath: String
  private let currentItem: () -> PlayableItem?
  private let coordinateSession: (AVPlayerPlaybackCoordinator) -> Void
  nonisolated private let contentIdentity = SharePlayContentIdentity()

  init(
    contentIdentifier: String,
    relativePath: String,
    currentItem: @escaping () -> PlayableItem?,
    coordinateSession: @escaping (AVPlayerPlaybackCoordinator) -> Void
  ) {
    self.contentIdentifier = contentIdentifier
    self.relativePath = relativePath
    self.currentItem = currentItem
    self.coordinateSession = coordinateSession
    super.init()
  }

  func prepareForPlayback(of playerItem: AVPlayerItem?) {
    guard let playerItem else { return }
    let identifier = currentItem().flatMap { item in
      item.relativePath == relativePath ? groupContentIdentifier(contentIdentifier, for: playerItem, in: item) : nil
    }
    contentIdentity.update(identifier, for: playerItem)
  }

  func coordinate(_ coordinator: AVPlayerPlaybackCoordinator) {
    coordinator.delegate = self
    coordinateSession(coordinator)
  }

  func stopCoordinating(_ coordinator: AVPlayerPlaybackCoordinator) {
    // No explicit uncoordinate API: the service leaves or ends the GroupSession.
    coordinator.delegate = nil
  }

  /// The session a play of ours gets from `PhonePlayerPlatform`, which may not start this one:
  /// its failure is fatal, and the group can resume while the app is in the background.
  /// A failure here is logged, and playback is left to the player.
  func activateAudioSession() {
    do {
      let audioSession = AVAudioSession.sharedInstance()
      try audioSession.setCategory(.playback, mode: .spokenAudio, options: [])
      try audioSession.setActive(true)
    } catch {
      Self.logger.error("Failed to activate the audio session for group playback: \(error)")
    }
  }

  nonisolated func playbackCoordinator(
    _ coordinator: AVPlayerPlaybackCoordinator,
    identifierFor playerItem: AVPlayerItem
  ) -> String {
    contentIdentity.identifier(for: playerItem)
  }

  /// Bound books use one item per audio file. Ordinals keep participants on different
  /// files waiting for each other without depending on device-local file names.
  private func groupContentIdentifier(
    _ baseIdentifier: String,
    for playerItem: AVPlayerItem,
    in item: PlayableItem
  ) -> String {
    var files = [String]()
    for chapter in item.chapters where !files.contains(chapter.relativePath) {
      files.append(chapter.relativePath)
    }

    guard files.count > 1 else { return baseIdentifier }
    guard let ordinal = fileOrdinal(for: playerItem, files: files, in: item) else {
      return baseIdentifier + "|file:unknown"
    }
    return baseIdentifier + "|file:\(ordinal)"
  }

  private func fileOrdinal(for playerItem: AVPlayerItem, files: [String], in item: PlayableItem) -> Int? {
    if let assetURL = (playerItem.asset as? AVURLAsset)?.url,
      let chapter = item.chapters.first(where: { $0.fileURL == assetURL || $0.remoteURL == assetURL })
    {
      return files.firstIndex(of: chapter.relativePath)
    }
    return files.firstIndex(of: item.currentChapter.relativePath)
  }
}

/// AVFoundation's delegate is nonisolated. Only precomputed strings cross that boundary;
/// neither the mutable book nor AVPlayerItem.asset is read from the callback. Weak keys
/// let old player items disappear instead of retaining one entry per chapter forever.
private final class SharePlayContentIdentity: @unchecked Sendable {
  private let lock = NSLock()
  private let identifiers = NSMapTable<AVPlayerItem, NSString>(keyOptions: [.weakMemory, .objectPointerPersonality], valueOptions: .strongMemory)
  /// What an item outside the session's book reports. This device's alone: no participant's content
  /// matches it, another book with the same fingerprint as a group's included.
  private let uncoordinatedIdentifier = "bookplayer.shareplay.uncoordinated." + UUID().uuidString

  /// `nil` for an item outside the session's book
  func update(_ identifier: String?, for playerItem: AVPlayerItem) {
    lock.withLock {
      if let identifier {
        identifiers.setObject(identifier as NSString, forKey: playerItem)
      } else {
        identifiers.removeObject(forKey: playerItem)
      }
    }
  }

  func identifier(for playerItem: AVPlayerItem) -> String {
    lock.withLock {
      identifiers.object(forKey: playerItem) as String? ?? uncoordinatedIdentifier
    }
  }
}
