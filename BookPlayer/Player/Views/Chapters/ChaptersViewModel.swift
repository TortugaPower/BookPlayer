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
  private let libraryService: LibraryServiceProtocol

  init(playerManager: PlayerManagerProtocol, libraryService: LibraryServiceProtocol) {
    self.playerManager = playerManager
    self.libraryService = libraryService
    super.init(
      chapters: playerManager.currentItem?.chapters ?? [],
      currentChapter: playerManager.currentItem?.currentChapter
    )
  }

  override func handleChapterSelected(_ chapter: PlayableChapter) {
    self.playerManager.jumpToChapter(chapter)
  }

  /// Re-parsing only applies to single-file books; bound books and folders derive their
  /// chapters from constituent files, so there's no embedded chapter track to re-read.
  override var canReloadChapters: Bool {
    playerManager.currentItem?.isBoundBook == false
  }

  @MainActor
  override func reloadChapters() async {
    guard let currentItem = playerManager.currentItem, currentItem.isBoundBook == false else {
      return
    }

    let relativePath = currentItem.relativePath
    let fileURL = DataManager.getProcessedFolderURL().appendingPathComponent(relativePath)
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      // The file must be downloaded first, through the usual library download flow.
      currentAlert = Self.infoAlert(message: "reparse_chapters_download_description".localized)
      return
    }

    isReloadingChapters = true
    defer { isReloadingChapters = false }

    guard let newCount = await libraryService.reloadChapters(relativePath: relativePath) else {
      currentAlert = Self.infoAlert(message: "reparse_chapters_none_description".localized)
      return
    }

    // Rebuild the player's item so the new chapters take effect everywhere (scrubber, now
    // playing, end-of-chapter sleep timer), then refresh this screen's list from it.
    playerManager.reloadCurrentItem()
    chapters = playerManager.currentItem?.chapters ?? []
    currentChapter = playerManager.currentItem?.currentChapter

    currentAlert = Self.infoAlert(
      title: "reparse_chapters_found_title".localized,
      message: String.localizedStringWithFormat("reparse_chapters_found_description".localized, newCount)
    )
  }

  private static func infoAlert(title: String? = nil, message: String) -> BPAlertContent {
    BPAlertContent(title: title, message: message, style: .alert, actionItems: [.okAction])
  }
}
