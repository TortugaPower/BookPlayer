//
//  OrientationLock.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/10/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import UIKit

/// The "Lock orientation" setting, enforced through supported orientations. iOS honors those on
/// iPhone, and on iPhone Duo only while closed: iPad ignores them because the app supports
/// multitasking, and so does iPhone Duo's inner display.
enum OrientationLock {
  private static let key = Constants.UserDefaults.orientationLock

  static func supportedOrientations(in defaults: UserDefaults = .standard) -> UIInterfaceOrientationMask {
    guard
      defaults.object(forKey: key) != nil,
      let orientation = UIDeviceOrientation(rawValue: defaults.integer(forKey: key))
    else { return .all }

    return orientation.isLandscape ? .landscape : .portrait
  }

  /// Saves the interface's orientation, not the device's: a phone lying flat reports face up,
  /// which would lock a landscape interface to portrait
  static func save(_ interfaceOrientation: UIInterfaceOrientation?, in defaults: UserDefaults = .standard) {
    /// Stored as a device orientation, the format earlier versions saved
    let orientation: UIDeviceOrientation = interfaceOrientation?.isLandscape == true ? .landscapeLeft : .portrait
    defaults.set(orientation.rawValue, forKey: key)
  }

  static func clear(in defaults: UserDefaults = .standard) {
    defaults.removeObject(forKey: key)
  }
}
