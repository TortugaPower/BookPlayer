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

  func getPlayableItem(from item: LibraryItem) throws -> PlayableItem? {
    return nil
  }

  func getFirstPlayableItem(in folder: Folder, isUnfinished: Bool?) throws -> PlayableItem? {
    return nil
  }
}
