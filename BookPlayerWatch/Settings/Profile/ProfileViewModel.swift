//
//  ProfileViewModel.swift
//  BookPlayerWatch
//
//  Created by Gianni Carlo on 11/11/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import BookPlayerWatchKit
import Foundation
import RevenueCat

@MainActor
class ProfileViewModel: ObservableObject {
  private let keychain = KeychainService()

  func handleLogOut() async throws {
    try keychain.remove(.token)
    _ = try await Purchases.shared.logOut()
    UserDefaults.standard.removeObject(forKey: "userEmail")
    /// Delete downloaded files
  }
}
