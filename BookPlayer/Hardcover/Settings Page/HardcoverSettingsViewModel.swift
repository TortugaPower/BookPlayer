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

  init(hardcoverService: HardcoverServiceProtocol) {
    self.hardcoverService = hardcoverService

    super.init(
      isSignedIn: hardcoverService.isSignedInWithOAuth,
      connectedUsername: hardcoverService.connectedUsername
    )
  }

  /// Shown as signed out right away: the sign-in is forgotten at once, but revoking it waits on the network
  @MainActor
  override func onLogOutTapped() {
    let hardcoverService = hardcoverService

    Task {
      await hardcoverService.disconnect()
    }

    isSignedIn = false
    connectedUsername = nil
  }

  @MainActor
  override func onSignInTapped(authenticate: @escaping (URL) async throws -> URL) async {
    isSigningIn = true
    defer { isSigningIn = false }

    do {
      try await hardcoverService.signIn(authenticate: authenticate)
    } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
      /// Closed by the user: nothing to report
    } catch {
      signInFailed = true
    }

    isSignedIn = hardcoverService.isSignedInWithOAuth
    connectedUsername = hardcoverService.connectedUsername
  }
}
