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
final class HardcoverSettingsViewModel: HardcoverSettingsView.Model {
  private var hardcoverService: HardcoverServiceProtocol

  @AppStorage(Constants.UserDefaults.hardcoverAutoMatch, store: UserDefaults.sharedDefaults)
  private var storedAutoMatch = false
  
  @AppStorage(Constants.UserDefaults.hardcoverAutoAddWantToRead, store: UserDefaults.sharedDefaults)
  private var storedAutoAddWantToRead = true

  @AppStorage(Constants.UserDefaults.hardcoverReadingThreshold, store: UserDefaults.sharedDefaults)
  private var storedReadingThreshold = 1.0

  init(hardcoverService: HardcoverServiceProtocol) {
    self.hardcoverService = hardcoverService
    
    super.init(
      accessToken: hardcoverService.authorization ?? "",
      showUnlinkButton: hardcoverService.authorization != nil
    )

    self.autoMatch = storedAutoMatch
    self.autoAddWantToRead = storedAutoAddWantToRead
    self.readingThreshold = storedReadingThreshold
  }

  @MainActor
  override func onSaveTapped() {
    hardcoverService.authorization = accessToken
    storedAutoMatch = autoMatch
    storedAutoAddWantToRead = autoAddWantToRead
    storedReadingThreshold = readingThreshold
  }

  @MainActor
  override func onUnlinkTapped() {
    hardcoverService.authorization = nil
  }
}
