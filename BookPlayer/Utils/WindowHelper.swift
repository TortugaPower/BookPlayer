//
//  WindowHelper.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import UIKit

@MainActor
enum WindowHelper {
  /// Returns the key window of the currently active scene.
  static var activeWindow: UIWindow? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }?
      .windows.first { $0.isKeyWindow }
  }
}
