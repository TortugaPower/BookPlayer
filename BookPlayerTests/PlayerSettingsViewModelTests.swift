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
    UserDefaults.standard.removeObject(forKey: Constants.UserDefaults.playerListPrefersBookmarks.rawValue)
    self.sut = PlayerSettingsViewModel()
  }

  func testInitialization() {
    XCTAssertFalse(self.sut.playerListPrefersBookmarks)

    UserDefaults.standard.set(true, forKey: Constants.UserDefaults.playerListPrefersBookmarks.rawValue)

    let secondViewModel = PlayerSettingsViewModel()
    XCTAssertTrue(secondViewModel.playerListPrefersBookmarks)
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
}
