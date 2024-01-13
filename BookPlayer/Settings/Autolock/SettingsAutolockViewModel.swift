//
//  SettingsAutolockViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/1/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import SwiftUI

protocol SettingsAutolockViewModelProtocol: ObservableObject {
  var navigationTitle: String { get }

  var autolockDisabled: Bool { get set }
  var onlyWhenPoweredEnabled: Bool { get set }

  func dismiss()
}

final class SettingsAutolockViewModel: SettingsAutolockViewModelProtocol {
  /// Available routes
  enum Routes {
    case dismiss
  }

  // MARK: - Properties

  /// Callback to handle actions on this screen
  var onTransition: BPTransition<Routes>?

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

  func dismiss() {
    onTransition?(.dismiss)
  }
}
