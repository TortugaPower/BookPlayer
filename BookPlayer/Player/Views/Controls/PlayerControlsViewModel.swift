//
//  PlayerControlsViewModel.swift
//  BookPlayer
//
//  Created by Pavel Kyzmin on 09.01.2022.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation
import SwiftUI

class PlayerControlsViewModel: PlayerControlsView.Model {
  let playerManager: PlayerManagerProtocol
  private var disposeBag = Set<AnyCancellable>()

  init(playerManager: PlayerManagerProtocol) {
    self.playerManager = playerManager

    super.init(
      currentSpeed: Double(playerManager.currentSpeed),
      isBoostVolumeEnabled: UserDefaults.standard.bool(forKey: Constants.UserDefaults.boostVolumeEnabled)
    )

    bindObservers()
  }

  private func bindObservers() {
    playerManager.currentSpeedPublisher()
      .removeDuplicates()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] speed in
        self?.currentSpeed = round(Double(speed) * 100) / 100.0
      }
      .store(in: &disposeBag)

    /// The setting can also change in Settings or from CarPlay while the player is open
    UserDefaults.standard.publisher(for: \.userSettingsBoostVolume, options: [.new])
      .receive(on: DispatchQueue.main)
      .sink { [weak self] isEnabled in
        self?.isBoostVolumeEnabled = isEnabled
      }
      .store(in: &disposeBag)
  }

  override func handleSpeedChange(_ speed: Double) {
    let roundedValue = round(speed * 100) / 100.0

    guard currentSpeed != roundedValue else { return }

    playerManager.setSpeed(Float(roundedValue))
  }

  override func handleBoostVolumeToggle(_ enabled: Bool) {
    /// At once, so the switch doesn't snap back until the setting's change arrives
    isBoostVolumeEnabled = enabled
    UserDefaults.standard.set(enabled, forKey: Constants.UserDefaults.boostVolumeEnabled)

    playerManager.setBoostVolume(enabled)
  }
}
