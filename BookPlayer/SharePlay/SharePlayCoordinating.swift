//
//  SharePlayCoordinating.swift
//  BookPlayer
//
//  Created by dawsonamf on 6/28/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import GroupActivities

/// iOS-only surface for handing SharePlay group sessions to the player.
/// Lives outside `PlayerManagerProtocol` because that protocol is shared with
/// the watch target, which has no GroupActivities support.
protocol SharePlayCoordinating: PlayerManagerProtocol {
  /// `relativePath` is the local item matched to the session's book; coordination
  /// is scoped to it so other content never reports the session's identity
  func coordinatePlayback(with session: GroupSession<AudioBookActivity>, for relativePath: String)
  func stopCoordinatingPlayback()
}
