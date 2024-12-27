//
//  PlayableItemMock.swift
//  BookPlayerTests
//
//  Created by gianni.carlo on 5/6/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation

extension PlayableItem {
  static var mock: PlayableItem {
    return PlayableItem(
      title: "test-title",
      author: "test-author",
      chapters: [
        PlayableChapter(
          title: "test-chapter",
          author: "test-author",
          start: 0,
          duration: 100,
          relativePath: "test-path",
          remoteURL: nil,
          index: 0
        )
      ],
      currentTime: 0,
      duration: 100,
      relativePath: "test-path",
      parentFolder: nil,
      percentCompleted: 0,
      lastPlayDate: nil,
      isFinished: false,
      isBoundBook: false
    )
  }

  static func mockWithExtension(_ fileExtension: String) -> PlayableItem {
    return PlayableItem(
      title: "test-title",
      author: "test-author",
      chapters: [
        PlayableChapter(
          title: "test-chapter",
          author: "test-author",
          start: 0,
          duration: 100,
          relativePath: "test-path",
          remoteURL: nil,
          index: 0
        )
      ],
      currentTime: 0,
      duration: 100,
      relativePath: "test-path.\(fileExtension)",
      parentFolder: nil,
      percentCompleted: 0,
      lastPlayDate: nil,
      isFinished: false,
      isBoundBook: false
    )
  }
}
