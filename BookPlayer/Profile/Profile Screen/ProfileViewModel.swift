//
//  ProfileViewModel.swift
//  BookPlayer
//
//  Created by gianni.carlo on 12/3/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation

class ProfileViewModel: BaseViewModel<ProfileCoordinator> {
  func showSettings() {
    self.coordinator.showSettings()
  }

  func showAccount() {
    self.coordinator.showAccount()
  }
}
