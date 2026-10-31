//
//  HardcoverSettingsViewModel.swift
//  BookPlayer
//
//  Created by Jeremy Grenier on 6/27/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import AuthenticationServices
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
      isConnected: hardcoverService.isConnected,
      isSignedInWithOAuth: hardcoverService.isSignedInWithOAuth,
      connectedUsername: hardcoverService.connectedUsername,
      needsSignInAgain: hardcoverService.needsSignInAgain,
      canSignIn: HardcoverOAuth.isAvailable
    )

    self.autoMatch = storedAutoMatch
    self.autoAddWantToRead = storedAutoAddWantToRead
    self.readingThreshold = storedReadingThreshold
  }

  @MainActor
  override func onSaveTapped() {
    /// Signed in, the key field is hidden and empty: there's no key to save
    if !hardcoverService.isSignedInWithOAuth {
      hardcoverService.authorization = accessToken
    }
    storedAutoMatch = autoMatch
    storedAutoAddWantToRead = autoAddWantToRead
    storedReadingThreshold = readingThreshold
  }

  @MainActor
  override func onUnlinkTapped() {
    let hardcoverService = hardcoverService

    Task {
      await hardcoverService.disconnect()
    }
  }

  @MainActor
  override func onSignInTapped(authenticate: @escaping (URL) async throws -> URL) async {
    isSigningIn = true
    defer { isSigningIn = false }

    do {
      try await hardcoverService.signIn(authenticate: authenticate)
      accessToken = ""
    } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
      /// Closed by the user: nothing to report
    } catch {
      signInFailed = true
    }

    isConnected = hardcoverService.isConnected
    isSignedInWithOAuth = hardcoverService.isSignedInWithOAuth
    connectedUsername = hardcoverService.connectedUsername
    needsSignInAgain = hardcoverService.needsSignInAgain
  }
}
