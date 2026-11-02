//
//  OrientationLockTests.swift
//  BookPlayerTests
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import XCTest

@testable import BookPlayer
@testable import BookPlayerKit

/// The lock is stored as a device orientation, the format earlier versions saved, so locks set
/// before the switch to the interface's orientation must keep working.
final class OrientationLockTests: XCTestCase {
  private let suiteName = "OrientationLockTests"
  private var defaults: UserDefaults!

  override func setUp() {
    super.setUp()
    defaults = UserDefaults(suiteName: suiteName)
    defaults.removePersistentDomain(forName: suiteName)
  }

  override func tearDown() {
    defaults.removePersistentDomain(forName: suiteName)
    defaults = nil
    super.tearDown()
  }

  func testNothingSaved_allowsEveryOrientation() {
    XCTAssertEqual(OrientationLock.supportedOrientations(in: defaults), .all)
  }

  func testValuesSavedByEarlierVersions() {
    let cases: [(UIDeviceOrientation, UIInterfaceOrientationMask)] = [
      (.portrait, .portrait),
      (.portraitUpsideDown, .portrait),
      (.landscapeLeft, .landscape),
      (.landscapeRight, .landscape),
      /// A phone lying flat, which earlier versions could save
      (.faceUp, .portrait),
      (.faceDown, .portrait),
      (.unknown, .portrait),
    ]

    for (saved, expected) in cases {
      defaults.set(saved.rawValue, forKey: Constants.UserDefaults.orientationLock)
      XCTAssertEqual(
        OrientationLock.supportedOrientations(in: defaults),
        expected,
        "saved device orientation \(saved.rawValue)"
      )
    }
  }

  func testSave_locksTheInterfaceOrientation() {
    let cases: [(UIInterfaceOrientation?, UIInterfaceOrientationMask)] = [
      (.portrait, .portrait),
      (.portraitUpsideDown, .portrait),
      (.landscapeLeft, .landscape),
      (.landscapeRight, .landscape),
      (.unknown, .portrait),
      (nil, .portrait),
    ]

    for (interfaceOrientation, expected) in cases {
      OrientationLock.save(interfaceOrientation, in: defaults)
      XCTAssertEqual(
        OrientationLock.supportedOrientations(in: defaults),
        expected,
        "saved interface orientation \(String(describing: interfaceOrientation?.rawValue))"
      )
    }
  }

  func testClear_unlocks() {
    OrientationLock.save(.landscapeLeft, in: defaults)
    OrientationLock.clear(in: defaults)

    XCTAssertNil(defaults.object(forKey: Constants.UserDefaults.orientationLock))
    XCTAssertEqual(OrientationLock.supportedOrientations(in: defaults), .all)
  }
}
