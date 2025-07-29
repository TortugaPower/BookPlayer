//
//  SettingsAutolockViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/1/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

final class SettingsAutolockViewModel: ObservableObject {
  // MARK: - Properties

  @Published var autolockDisabled: Bool {
    didSet {
      UserDefaults.standard.set(
        autolockDisabled,
        forKey: Constants.UserDefaults.autolockDisabled
      )
    }
  }

  @Published var onlyWhenPoweredEnabled: Bool {
    didSet {
      UserDefaults.standard.set(
        onlyWhenPoweredEnabled,
        forKey: Constants.UserDefaults.autolockDisabledOnlyWhenPowered
      )
    }
  }

  let navigationTitle = "settings_autlock_section_title".localized

  init() {
    autolockDisabled = UserDefaults.standard.bool(
      forKey: Constants.UserDefaults.autolockDisabled
    )
    onlyWhenPoweredEnabled = UserDefaults.standard.bool(
      forKey: Constants.UserDefaults.autolockDisabledOnlyWhenPowered
    )
  }
}
