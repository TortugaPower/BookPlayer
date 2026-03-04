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
  /// Safe to call from non-isolated contexts via `MainActor.assumeIsolated`
  /// when you know you're already on the main thread (e.g., UIKit callbacks).
  nonisolated static var activeWindow: UIWindow? {
    MainActor.assumeIsolated {
      UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first { $0.activationState == .foregroundActive }?
        .windows.first { $0.isKeyWindow }
    }
  }
}
