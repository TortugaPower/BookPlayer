//
//  HardcoverSettingsViewModel.swift
//  BookPlayer
//
//  Created by Jeremy Grenier on 6/27/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import Get
import JellyfinAPI
import SwiftUI

@MainActor
final class HardcoverSettingsViewModel: HardcoverSettingsView.Model, BPLogger {
  private var hardcoverService: HardcoverServiceProtocol

  private var disposeBag = Set<AnyCancellable>()

  init(hardcoverService: HardcoverServiceProtocol = HardcoverService()) {
    self.hardcoverService = hardcoverService
    super.init(accessToken: hardcoverService.authorization ?? "")

    $accessToken.sink { [weak self] value in
      Task { @MainActor in
        self?.isSaveEnabled = !value.isEmpty && value != self?.hardcoverService.authorization
      }
    }.store(in: &disposeBag)
  }

  @MainActor
  override func onSaveTapped() {
    hardcoverService.authorization = accessToken
  }
}
