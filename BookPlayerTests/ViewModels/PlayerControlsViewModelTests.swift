//
//  PlayerControlsViewModelTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

@testable import BookPlayer
@testable import BookPlayerKit
import Combine
import XCTest

@MainActor
final class PlayerControlsViewModelTests: XCTestCase {
  private var playerManagerMock: PlayerManagerProtocolMock!
  private var savedBoostVolume: Any?
  private var sut: PlayerControlsViewModel!

  override func setUp() {
    super.setUp()
    savedBoostVolume = UserDefaults.standard.object(forKey: Constants.UserDefaults.boostVolumeEnabled)
    UserDefaults.standard.set(false, forKey: Constants.UserDefaults.boostVolumeEnabled)
    playerManagerMock = PlayerManagerProtocolMock()
    playerManagerMock.currentSpeed = 1
    playerManagerMock.currentSpeedPublisherReturnValue = Just(1).eraseToAnyPublisher()
    sut = PlayerControlsViewModel(playerManager: playerManagerMock)
  }

  override func tearDown() {
    sut = nil
    UserDefaults.standard.set(savedBoostVolume, forKey: Constants.UserDefaults.boostVolumeEnabled)
    super.tearDown()
  }

  /// The switch reads the model right after it's flipped: an older value would snap it back
  func testFlippingBoostVolumeShowsTheNewValueAtOnce() {
    sut.handleBoostVolumeToggle(true)

    XCTAssertTrue(sut.isBoostVolumeEnabled)
    XCTAssertEqual(playerManagerMock.setBoostVolumeReceivedNewValue, true)
  }

  /// Settings and CarPlay change the same setting while the player is open
  func testBoostVolumeChangedElsewhereReachesTheModel() async {
    UserDefaults.standard.set(true, forKey: Constants.UserDefaults.boostVolumeEnabled)

    let deadline = Date().addingTimeInterval(2)
    while !sut.isBoostVolumeEnabled, Date() < deadline {
      try? await Task.sleep(nanoseconds: 5_000_000)
    }
    XCTAssertTrue(sut.isBoostVolumeEnabled)
  }
}
