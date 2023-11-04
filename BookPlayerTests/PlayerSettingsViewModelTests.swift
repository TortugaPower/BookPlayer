//
//  PlayerSettingsViewModelTests.swift
//  BookPlayerTests
//
//  Created by gianni.carlo on 22/5/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation

@testable import BookPlayer
@testable import BookPlayerKit
import Combine
import XCTest

class PlayerSettingsViewModelTests: XCTestCase {
  var sut: PlayerSettingsViewModel!

  override func setUp() {
    UserDefaults.standard.removeObject(forKey: Constants.UserDefaults.playerListPrefersBookmarks)
    UserDefaults.sharedDefaults.removeObject(forKey: Constants.UserDefaults.chapterContextEnabled)
    UserDefaults.sharedDefaults.removeObject(forKey: Constants.UserDefaults.remainingTimeEnabled)

    self.sut = PlayerSettingsViewModel()
  }

  func testInitialization() {
    XCTAssertFalse(self.sut.playerListPrefersBookmarks)
    XCTAssertFalse(self.sut.prefersChapterContext)
    XCTAssertFalse(self.sut.prefersRemainingTime)

    UserDefaults.standard.set(true, forKey: Constants.UserDefaults.playerListPrefersBookmarks)
    UserDefaults.sharedDefaults.set(true, forKey: Constants.UserDefaults.chapterContextEnabled)
    UserDefaults.sharedDefaults.set(true, forKey: Constants.UserDefaults.remainingTimeEnabled)

    let secondViewModel = PlayerSettingsViewModel()
    XCTAssertTrue(secondViewModel.playerListPrefersBookmarks)
    XCTAssertTrue(secondViewModel.prefersChapterContext)
    XCTAssertTrue(secondViewModel.prefersRemainingTime)
  }

  func testGettingTitleForPlayerListPreference() {
    XCTAssertTrue(self.sut.getTitleForPlayerListPreference(true) == "Bookmarks")
    XCTAssertTrue(self.sut.getTitleForPlayerListPreference(false) == "Chapters")
  }

  func testOptionSelected() {
    self.sut.handleOptionSelected(.bookmarks)
    XCTAssertTrue(self.sut.playerListPrefersBookmarks)
    self.sut.handleOptionSelected(.chapters)
    XCTAssertFalse(self.sut.playerListPrefersBookmarks)
  }

  func testPrefersChapterContext() {
    self.sut.handlePrefersChapterContext(true)
    XCTAssertTrue(self.sut.prefersChapterContext)
    self.sut.handlePrefersChapterContext(false)
    XCTAssertFalse(self.sut.prefersChapterContext)
  }

  func testPrefersRemainingTime() {
    self.sut.handlePrefersRemainingTime(true)
    XCTAssertTrue(self.sut.prefersRemainingTime)
    self.sut.handlePrefersRemainingTime(false)
    XCTAssertFalse(self.sut.prefersRemainingTime)
  }
}
