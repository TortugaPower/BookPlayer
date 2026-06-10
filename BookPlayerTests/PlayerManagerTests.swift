//
//  PlayerManagerTests.swift
//  BookPlayerTests
//
//  Created by gianni.carlo on 18/5/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import Foundation
import MediaPlayer

@testable import BookPlayer
@testable import BookPlayerKit
import Combine
import XCTest

class PlayerManagerTests: XCTestCase {
  var playbackServiceMock: PlaybackServiceProtocolMock!
  var sut: PlayerManager!

  override func setUp() {
    // Clean up stored configs
    UserDefaults.sharedDefaults.removeObject(forKey: Constants.UserDefaults.chapterContextEnabled)
    UserDefaults.sharedDefaults.removeObject(forKey: Constants.UserDefaults.remainingTimeEnabled)

    self.playbackServiceMock = PlaybackServiceProtocolMock()
    /// Mirror production `PlaybackService.updatePlaybackTime(item:time:)`, which advances the
    /// playhead, so seek targets are observable in tests instead of staying frozen.
    self.playbackServiceMock.updatePlaybackTimeItemTimeClosure = { item, time in
      item.currentTime = time
    }
    self.sut = PlayerManager(
      libraryService: LibraryServiceProtocolMock(),
      playbackService: playbackServiceMock,
      syncService: SyncServiceProtocolMock(),
      speedService: SpeedServiceProtocolMock(),
      shakeMotionService: ShakeMotionServiceProtocolMock(),
      widgetReloadService: WidgetReloadService()
    )
  }

  private func generatePlayableItem() -> PlayableItem {
    let testChapter = PlayableChapter(
      title: "test chapter 1",
      author: "test author chapter",
      start: 0,
      duration: 50,
      relativePath: "",
      remoteURL: nil,
      index: 0
    )
    let testChapter2 = PlayableChapter(
      title: "test chapter 2",
      author: "test author chapter 2",
      start: 51,
      duration: 100,
      relativePath: "",
      remoteURL: nil,
      index: 1
    )
    return PlayableItem(
      title: "test book",
      author: "test author",
      chapters: [testChapter, testChapter2],
      currentTime: 0,
      duration: 100,
      relativePath: "",
      uuid: "LEGACY_UUID",
      parentFolder: nil,
      percentCompleted: 10,
      lastPlayDate: nil,
      isFinished: false,
      isBoundBook: false
    )
  }

  /// Two-chapter item using production's 1-based chapter indexing, so
  /// `nextChapter`/`previousChapter` navigation resolves correctly.
  private func generateChapteredItem() -> PlayableItem {
    let chapter1 = PlayableChapter(
      title: "chapter 1",
      author: "author",
      start: 0,
      duration: 50,
      relativePath: "",
      remoteURL: nil,
      index: 1
    )
    let chapter2 = PlayableChapter(
      title: "chapter 2",
      author: "author",
      start: 51,
      duration: 100,
      relativePath: "",
      remoteURL: nil,
      index: 2
    )
    return PlayableItem(
      title: "test book",
      author: "test author",
      chapters: [chapter1, chapter2],
      currentTime: 0,
      duration: 151,
      relativePath: "",
      uuid: "LEGACY_UUID",
      parentFolder: nil,
      percentCompleted: 10,
      lastPlayDate: nil,
      isFinished: false,
      isBoundBook: false
    )
  }

  func testUpdatingEmptyNowPlayingBookTime() {
    self.sut.setNowPlayingBookTime()

    XCTAssertNil(self.sut.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate])
    XCTAssertNil(self.sut.nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime])
    XCTAssertNil(self.sut.nowPlayingInfo[MPMediaItemPropertyPlaybackDuration])
    XCTAssertNil(self.sut.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackProgress])
  }

  func testUpdatingGlobalNowPlayingBookTime() {
    // playback speed shouldn't affect duration time set
    self.sut.setSpeed(2)
    // mocked playable item
    let playableItem = generatePlayableItem()
    playableItem.currentTime = 20

    self.sut.currentItem = playableItem
    self.sut.setNowPlayingBookTime()

    XCTAssertTrue((self.sut.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] as? Double) == 1)
    XCTAssertTrue((self.sut.nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double) == 20)
    XCTAssertTrue((self.sut.nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] as? Double) == 100)
    XCTAssertTrue((self.sut.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackProgress] as? Double) == 0.2)
  }

  func testUpdatingGlobalRemainingNowPlayingBookTime() {
    // playback speed should affect duration time set
    self.sut.setSpeed(2)
    UserDefaults.sharedDefaults.set(true, forKey: Constants.UserDefaults.remainingTimeEnabled)
    // mocked playable item
    let playableItem = generatePlayableItem()
    playableItem.currentTime = 20

    self.sut.currentItem = playableItem
    self.sut.setNowPlayingBookTime()

    XCTAssertTrue((self.sut.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] as? Double) == 1)
    XCTAssertTrue((self.sut.nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double) == 20)
    XCTAssertTrue((self.sut.nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] as? Double) == 60)
    XCTAssertTrue((self.sut.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackProgress] as? Double) == 0.2)
  }

  func testUpdatingChapterNowPlayingBookTime() {
    // playback speed shouldn't affect duration time set
    self.sut.setSpeed(2)
    UserDefaults.sharedDefaults.set(true, forKey: Constants.UserDefaults.chapterContextEnabled)
    // mocked playable item
    let playableItem = generatePlayableItem()
    playableItem.currentTime = 10

    self.sut.currentItem = playableItem
    self.sut.setNowPlayingBookTime()

    XCTAssertTrue((self.sut.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] as? Double) == 1)
    XCTAssertTrue((self.sut.nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double) == 10)
    XCTAssertTrue((self.sut.nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] as? Double) == 50)
    XCTAssertTrue((self.sut.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackProgress] as? Double) == 0.20)
  }

  func testUpdatingChapterRemainingNowPlayingBookTime() {
    // playback speed should affect duration time set
    self.sut.setSpeed(2)
    UserDefaults.sharedDefaults.set(true, forKey: Constants.UserDefaults.remainingTimeEnabled)
    UserDefaults.sharedDefaults.set(true, forKey: Constants.UserDefaults.chapterContextEnabled)
    // mocked playable item
    let playableItem = generatePlayableItem()
    playableItem.currentTime = 10

    self.sut.currentItem = playableItem
    self.sut.setNowPlayingBookTime()

    XCTAssertTrue((self.sut.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] as? Double) == 1)
    XCTAssertTrue((self.sut.nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double) == 10)
    XCTAssertTrue((self.sut.nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] as? Double) == 30)
    XCTAssertTrue((self.sut.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackProgress] as? Double) == 0.20)
  }

  func testUpdatingEmptyNowPlayingBookTitle() {
    let playableItem = generatePlayableItem()
    let chapter = playableItem.chapters.first!

    self.sut.setNowPlayingBookTitle(chapter: chapter)

    XCTAssertNil(self.sut.nowPlayingInfo[MPMediaItemPropertyTitle])
    XCTAssertNil(self.sut.nowPlayingInfo[MPMediaItemPropertyArtist])
    XCTAssertNil(self.sut.nowPlayingInfo[MPMediaItemPropertyAlbumTitle])
  }

  func testUpdatingNowPlayingBookTitle() {
    let playableItem = generatePlayableItem()
    let chapter = playableItem.chapters.first!

    self.sut.currentItem = playableItem
    self.sut.setNowPlayingBookTitle(chapter: chapter)

    XCTAssertTrue((self.sut.nowPlayingInfo[MPMediaItemPropertyTitle] as? String) == chapter.title)
    XCTAssertTrue((self.sut.nowPlayingInfo[MPMediaItemPropertyArtist] as? String) == playableItem.title)
    XCTAssertTrue((self.sut.nowPlayingInfo[MPMediaItemPropertyAlbumTitle] as? String) == playableItem.author)
  }

  func testGetNextPlayableBookSuccess() {
    playbackServiceMock.getPlayableItemAfterParentFolderAutoplayedRestartFinishedReturnValue = PlayableItem.mockWithExtension("mp3")

    let nextItem = sut.getNextPlayableBook(
      after: PlayableItem.mock,
      autoPlayed: true,
      restartFinished: true
    )

    XCTAssertNotNil(nextItem)
    XCTAssertTrue(playbackServiceMock.getPlayableItemAfterParentFolderAutoplayedRestartFinishedCallsCount == 1)
  }

  func testGetNextPlayableBookJpgFail() {
    /// Test unrecognized file
    playbackServiceMock
      .getPlayableItemAfterParentFolderAutoplayedRestartFinishedClosure = { relativePath, _, _, _ in
        return [PlayableItem.mockWithExtension("jpg")].filter({ $0.relativePath != relativePath }).first
      }

    let nextItem = sut.getNextPlayableBook(
      after: PlayableItem.mock,
      autoPlayed: true,
      restartFinished: true
    )

    XCTAssertNil(nextItem)
    XCTAssertTrue(playbackServiceMock.getPlayableItemAfterParentFolderAutoplayedRestartFinishedCallsCount == 2)
  }

  // MARK: - skipToPreviousChapter

  func testSkipToPreviousChapterMidChapterRestartsCurrentChapter() {
    let item = generateChapteredItem()
    item.currentChapter = item.chapters[1]  // chapter 2, starts at 51
    item.currentTime = 100  // well past the start threshold
    sut.currentItem = item

    sut.skipToPreviousChapter()

    // Restarts the current chapter (seeks to its start) rather than stepping back
    XCTAssertEqual(sut.currentItem?.currentChapter?.index, 2)
    XCTAssertEqual(sut.currentItem?.currentTime ?? 0, 51.1, accuracy: 0.0001)
    XCTAssertEqual(playbackServiceMock.getPlayableItemBeforeParentFolderCallsCount, 0)
  }

  func testSkipToPreviousChapterNearStartStepsToPreviousChapter() {
    let item = generateChapteredItem()
    item.currentChapter = item.chapters[1]  // chapter 2, starts at 51
    item.currentTime = 52  // within the start threshold
    sut.currentItem = item

    sut.skipToPreviousChapter()

    // Steps back to the previous chapter's start
    XCTAssertEqual(sut.currentItem?.currentChapter?.index, 1)
    XCTAssertEqual(sut.currentItem?.currentTime ?? -1, 0.1, accuracy: 0.0001)
    XCTAssertEqual(playbackServiceMock.getPlayableItemBeforeParentFolderCallsCount, 0)
  }

  func testSkipToPreviousChapterFirstChapterMidChapterRestartsInstead() {
    let item = generateChapteredItem()
    item.currentChapter = item.chapters[0]  // chapter 1, starts at 0
    item.currentTime = 30  // mid-chapter, past the threshold
    sut.currentItem = item

    sut.skipToPreviousChapter()

    // Restarts chapter 1 (seeks to its start) instead of jumping to the previous item
    XCTAssertEqual(sut.currentItem?.currentChapter?.index, 1)
    XCTAssertEqual(sut.currentItem?.currentTime ?? -1, 0.1, accuracy: 0.0001)
    XCTAssertEqual(playbackServiceMock.getPlayableItemBeforeParentFolderCallsCount, 0)
  }

  func testSkipToPreviousChapterFirstChapterNearStartPlaysPreviousItem() {
    let item = generateChapteredItem()
    item.currentChapter = item.chapters[0]  // chapter 1, starts at 0
    item.currentTime = 1  // within the start threshold, no previous chapter
    sut.currentItem = item

    sut.skipToPreviousChapter()

    // Falls back to the previous item without seeking within the current one
    XCTAssertEqual(playbackServiceMock.getPlayableItemBeforeParentFolderCallsCount, 1)
    XCTAssertEqual(sut.currentItem?.currentTime ?? -1, 1, accuracy: 0.0001)
  }
}
