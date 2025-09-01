//
//  AppHostingViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 13/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

final class AppHostingViewController<Content: View>: UIHostingController<Content> {
  override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    if UserDefaults.standard.object(forKey: Constants.UserDefaults.orientationLock) != nil,
       let orientation = UIDeviceOrientation(rawValue: UserDefaults.standard.integer(forKey: Constants.UserDefaults.orientationLock)) {
      return (orientation == .landscapeLeft || orientation == .landscapeRight)
      ? .landscape
      : .portrait
    } else {
      return .all
    }
  }
}
