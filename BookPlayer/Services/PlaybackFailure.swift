//
//  PlaybackFailure.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation

/// A playback failure on its way to whichever surface the user is on.
///
/// Carries the REASON rather than finished copy: the phone and the car word it differently and
/// offer different actions, so rendering belongs to the presenter. `PlayerManager` raises this
/// from two async paths — the metadata load and the player item's KVO status — long after the
/// caller that started playback has gone, which is why it cannot present the alert itself.
struct PlaybackFailure: Equatable {
  enum Reason: Equatable {
    /// No saved connection on this device matches the item's host: the server was never added
    /// here, or it was removed. Adding it in Media Servers is the fix.
    case missingConnection
    /// A stream URL resolved and playback still failed — server unreachable, network gone, or
    /// a token that no longer works.
    case streamUnavailable
    /// Everything else: a local file that won't open, an unrecognized AVFoundation error.
    case other
  }

  let reason: Reason
  /// Title and body exactly as the phone has always shown them, error code and `NSError` dump
  /// included — they are worth keeping for support threads. Neither reaches the car, which
  /// words its own single line: a domain and a `userInfo` dump is not dashboard copy.
  let phoneTitle: String
  let phoneMessage: String?
  /// Whether the Media Servers shortcut can actually fix this one. False when the tier cannot
  /// stream at all, since adding a server would not help.
  let canOfferMediaServers: Bool

  /// What the car says. One line, no error codes, and it always points at the phone — the car
  /// is never where a media server gets configured.
  ///
  /// Gated on `canOfferMediaServers` for the same reason the phone hides its shortcut: telling
  /// a tier that cannot stream to go connect a server is advice that leads nowhere. The two
  /// surfaces have to agree on that, or they hold different answers to one decision.
  var carPlayMessage: String {
    switch reason {
    case .missingConnection where canOfferMediaServers:
      return "carplay_missing_connection_message".localized
    case .missingConnection, .streamUnavailable, .other:
      return "carplay_playback_failed_message".localized
    }
  }
}
