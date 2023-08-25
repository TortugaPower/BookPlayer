//
//  PlayerViewModelTests.swift
//  BookPlayerTests
//
//  Created by gianni.carlo on 14/7/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import XCTest

@testable import BookPlayer
@testable import BookPlayerKit

final class PlayerViewModelTests: XCTestCase {
  
  var sut: PlayerViewModel!
  
  override func setUpWithError() throws {
    sut = PlayerViewModel(
      playerManager: PlayerManagerProtocolMock(),
      libraryService: LibraryServiceProtocolMock(),
      syncService: SyncServiceProtocolMock()
    )
  }
  
  override func tearDownWithError() throws {
    sut = nil
    UserDefaults.standard.removeObject(forKey: Constants.UserDefaults.customSleepTimerDuration)
  }
  
  func testSettingLastCustomSleepTimerDuration() {
    let initialValue = UserDefaults.standard.double(forKey: Constants.UserDefaults.customSleepTimerDuration)
    
    XCTAssert(initialValue == 0)
    
    sut.handleCustomSleepTimerOption(seconds: 20)
    
    let newValue = UserDefaults.standard.double(forKey: Constants.UserDefaults.customSleepTimerDuration)
    
    XCTAssert(newValue == 20)
  }
  
  func testFetchingLastCustomSleepTimerDuration() {
    let initialValue = sut.getLastCustomSleepTimerDuration()
    
    XCTAssertNil(initialValue)
    
    UserDefaults.standard.set(30, forKey: Constants.UserDefaults.customSleepTimerDuration)
    
    let storedValue = sut.getLastCustomSleepTimerDuration()
    
    XCTAssert(storedValue == 30)
  }
}
