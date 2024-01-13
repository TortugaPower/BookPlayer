//
//  SettingsAutoplayViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 7/1/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import SwiftUI

protocol SettingsAutoplayViewModelProtocol: ObservableObject {
  var navigationTitle: String { get }

  var autoplayLibraryEnabled: Bool { get set }
  var autoplayRestartFinishedEnabled: Bool { get set }

  func dismiss()
}

final class SettingsAutoplayViewModel: SettingsAutoplayViewModelProtocol {
  /// Available routes
  enum Routes {
    case dismiss
  }

  // MARK: - Properties

  /// Callback to handle actions on this screen
  var onTransition: BPTransition<Routes>?

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

  func dismiss() {
    onTransition?(.dismiss)
  }
}
