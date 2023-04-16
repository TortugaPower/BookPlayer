//
//  EmptyPlaybackServiceMock.swift
//  BookPlayerTests
//
//  Created by gianni.carlo on 18/5/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Foundation

/// Empty class meant to be subclassed to adjust service for test conditions
class EmptyPlaybackServiceMock: PlaybackServiceProtocol {
  func getFirstPlayableItem(in folder: BookPlayerKit.SimpleLibraryItem, isUnfinished: Bool?) throws -> BookPlayerKit.PlayableItem? {
    return nil
  }

  func getPlayableItem(from item: BookPlayerKit.SimpleLibraryItem) throws -> BookPlayerKit.PlayableItem? {
    return nil
  }

  func updatePlaybackTime(item: PlayableItem, time: Double) {}

  func getPlayableItem(before relativePath: String, parentFolder: String?) -> PlayableItem? {
    return nil
  }

  func getNextChapter(from item: PlayableItem) -> PlayableChapter? {
    return nil
  }

  func getPlayableItem(
    after relativePath: String,
    parentFolder: String?,
    autoplayed: Bool,
    restartFinished: Bool
  ) -> PlayableItem? {
    return nil
  }
}
