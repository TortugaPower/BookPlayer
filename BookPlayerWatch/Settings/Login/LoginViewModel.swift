//
//  LoginViewModel.swift
//  BookPlayerWatch
//
//  Created by Gianni Carlo on 11/11/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import AuthenticationServices
import BookPlayerWatchKit
import Foundation
import RevenueCat

@MainActor
class LoginViewModel: ObservableObject {
  private let provider: NetworkProvider<AccountAPI> = NetworkProvider(client: NetworkClient())
  private let keychain = KeychainService()

  func handleSignIn(_ authorization: ASAuthorization) async throws {
    switch authorization.credential {
    case let appleIDCredential as ASAuthorizationAppleIDCredential:
      guard
        let tokenData = appleIDCredential.identityToken,
        let token = String(data: tokenData, encoding: .utf8)
      else {
        throw AccountError.missingToken
      }

      let response: LoginResponse = try await provider.request(.login(token: token))
      try self.keychain.setAccessToken(response.token)
      _ = try await Purchases.shared.logIn(appleIDCredential.user)
      UserDefaults.standard.set(response.email, forKey: "userEmail")
    default:
      break
    }
  }
}
