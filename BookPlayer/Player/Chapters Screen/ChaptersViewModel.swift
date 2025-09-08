//
//  ChaptersViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 30/8/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation

final class ChaptersViewModel: ChaptersView.Model {
  private let playerManager: PlayerManagerProtocol

  init(playerManager: PlayerManagerProtocol) {
    self.playerManager = playerManager
    super.init(
      chapters: playerManager.currentItem?.chapters ?? [],
      currentChapter: playerManager.currentItem?.currentChapter
    )
  }

  override func handleChapterSelected(_ chapter: PlayableChapter) {
    self.playerManager.jumpToChapter(chapter)
  }
}
