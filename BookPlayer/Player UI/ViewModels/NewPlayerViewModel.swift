//
//  NewPlayerViewModel.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 10/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import SwiftUI

@MainActor
final class NewPlayerViewModel: ObservableObject {
  @State var chapterTitle: String = ""
  var progressData = ProgressData()
  
  private let libraryService: LibraryService
  private let playbackService: PlaybackService
  let playerManager: PlayerManager
  private let syncService: SyncService
  private var chapterBeforeSliderValueChange: PlayableChapter?
  private let sharedDefaults: UserDefaults
  private var prefersChapterContext: Bool
  private var prefersRemainingTime: Bool
  
  private var disposeBag = Set<AnyCancellable>()
  private var playingProgressSubscriber: AnyCancellable?
  private var currentChapterSubscriber: AnyCancellable?
  private var updateProgressObserver: NSKeyValueObservation?

  func hasChapter(before chapter: PlayableChapter?) -> Bool {
    guard let chapter = chapter else { return false }
    return self.playerManager.currentItem?.hasChapter(before: chapter) ?? false
  }

  func hasChapter(after chapter: PlayableChapter?) -> Bool {
    guard let chapter = chapter else { return false }
    return self.playerManager.currentItem?.hasChapter(after: chapter) ?? false
  }

  init(
    libraryService: LibraryService,
    playbackService: PlaybackService,
    playerManager: PlayerManager,
    syncService: SyncService,
  ) {
    self.libraryService = libraryService
    self.playbackService = playbackService
    self.playerManager = playerManager
    self.syncService = syncService
    let sharedDefaults = UserDefaults.sharedDefaults
    self.prefersChapterContext = sharedDefaults.bool(forKey: Constants.UserDefaults.chapterContextEnabled)
    self.prefersRemainingTime = sharedDefaults.bool(forKey: Constants.UserDefaults.remainingTimeEnabled)
    self.sharedDefaults = sharedDefaults
    
    bindBookPlayingProgressEvents()
  }
  
  func bindBookPlayingProgressEvents() {
    self.playingProgressSubscriber?.cancel()
    self.playingProgressSubscriber = NotificationCenter.default.publisher(for: .bookPlaying)
      .sink { [weak self] _ in
        guard let self = self else { return }
        self.recalculateProgress()
      }
  }
  
  func getBookCurrentTime() -> TimeInterval {
    return self.playerManager.currentItem?.currentTimeInContext(self.prefersChapterContext) ?? 0
  }
  
  func getBookMaxTime() -> TimeInterval {
    return self.playerManager.currentItem?.maxTimeInContext(
      prefersChapterContext: self.prefersChapterContext,
      prefersRemainingTime: self.prefersRemainingTime,
      at: self.playerManager.currentSpeed
    ) ?? 0
  }
  
  func recalculateProgress(_ item: PlayableItem? = nil) {
    let currentTime = self.getBookCurrentTime()
    let maxTimeInContext = self.getBookMaxTime()
    let progress: String
    let sliderValue: Float

    let currentItem = item ?? self.playerManager.currentItem

    if self.prefersChapterContext,
      let currentItem = currentItem,
      let currentChapter = currentItem.currentChapter
    {
      progress = String.localizedStringWithFormat(
        "player_chapter_description".localized,
        currentChapter.index,
        currentItem.chapters.count
      )
      sliderValue = Float((currentItem.currentTime - currentChapter.start) / currentChapter.duration)
    } else {
      progress = "\(Int(round((currentItem?.progressPercentage ?? 0) * 100)))%"
      sliderValue = Float(currentItem?.progressPercentage ?? 0)
    }

    // Update local chapter
    self.chapterBeforeSliderValueChange = currentItem?.currentChapter

    let prevChapterImageName =
      self.hasChapter(before: currentItem?.currentChapter)
      ? "chevron.left"
      : "chevron.left.2"
    let nextChapterImageName =
      self.hasChapter(after: currentItem?.currentChapter)
      ? "chevron.right"
      : "chevron.right.2"

    chapterTitle = currentItem?.currentChapter?.title
      ?? currentItem?.title
      ?? ""
    
    progressData.chapterTitle = chapterTitle
    progressData.progress = progress
    progressData.maxTime = maxTimeInContext
    progressData.currentTime = currentTime
    progressData.sliderValue = sliderValue
  }
}
