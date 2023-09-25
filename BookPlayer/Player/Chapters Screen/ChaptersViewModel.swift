//
//  ChaptersViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 30/8/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation

class ChaptersViewModel {
  enum Routes {
    case dismiss
  }

  var onTransition: BPTransition<Routes>?

  let playerManager: PlayerManagerProtocol

  init(playerManager: PlayerManagerProtocol) {
    self.playerManager = playerManager
  }

  func getItemChapters() -> [PlayableChapter]? {
    return self.playerManager.currentItem?.chapters
  }

  func getCurrentChapter() -> PlayableChapter? {
    return self.playerManager.currentItem?.currentChapter
  }

  // Don't set the chapter, set the new time which will set the chapter in didSet
  // Add a fraction of a second to make sure we start after the end of the previous chapter
  func handleChapterSelected(_ chapter: PlayableChapter) {
    self.playerManager.jumpToChapter(chapter)
  }

  func dismiss() {
    onTransition?(.dismiss)
  }
}
