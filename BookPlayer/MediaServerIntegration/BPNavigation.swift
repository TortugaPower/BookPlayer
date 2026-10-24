//
//  BPNavigation.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 7/6/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI

@MainActor
final class BPNavigation: ObservableObject {
  var dismiss: (() -> Void)?

  @Published var path = NavigationPath()
  /// Drives the subscribe flow. A sheet rather than a pushed destination, matching how
  /// every other paywall in the app is presented (SettingsView, AccountView) and keeping
  /// it clear of the edit-mode bottom toolbar.
  @Published var showingSubscribe = false

  nonisolated init() {}
}
