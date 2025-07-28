//
//  SettingsAutoplayViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 7/1/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

final class SettingsAutoplayViewModel: ObservableObject {
  // MARK: - Properties

  @Published var autoplayLibraryEnabled: Bool {
    didSet {
      UserDefaults.standard.set(
        autoplayLibraryEnabled,
        forKey: Constants.UserDefaults.autoplayEnabled
      )
    }
  }

  @Published var autoplayRestartFinishedEnabled: Bool {
    didSet {
      UserDefaults.standard.set(
        autoplayRestartFinishedEnabled,
        forKey: Constants.UserDefaults.autoplayRestartEnabled
      )
    }
  }

  let navigationTitle = "settings_autoplay_section_title".localized.localizedCapitalized

  init() {
    autoplayLibraryEnabled = UserDefaults.standard.bool(
      forKey: Constants.UserDefaults.autoplayEnabled
    )
    autoplayRestartFinishedEnabled = UserDefaults.standard.bool(
      forKey: Constants.UserDefaults.autoplayRestartEnabled
    )
  }
}
