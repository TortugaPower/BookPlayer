//
//  LoginViewModel.swift
//  BookPlayer
//
//  Created by gianni.carlo on 3/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import AuthenticationServices
import BookPlayerKit
import RevenueCat
import Foundation

class LoginViewModel: BaseViewModel<LoginCoordinator> {
  let accountService: AccountServiceProtocol

  init(accountService: AccountServiceProtocol) {
    self.accountService = accountService
  }

  func handleSignIn(authorization: ASAuthorization) {
    switch authorization.credential {
    case let appleIDCredential as ASAuthorizationAppleIDCredential:
      // email won't be there on subsequent approvals
      // (save locally in case account creation fails for some reason)
      self.accountService.updateAccount(
        id: appleIDCredential.user,
        email: appleIDCredential.email,
        donationMade: nil,
        hasSubscription: nil,
        accessToken: nil
      )

      Purchases.shared.logIn(appleIDCredential.user) { _, _, _ in }

      // TODO: network call to create the user in backend
      NotificationCenter.default.post(name: .accountUpdate, object: self)

      self.coordinator.showCompleteAccount()
    default:
      break
    }
  }

  func handleError(_ error: Error) {
    self.coordinator.showError(error)
  }
}
