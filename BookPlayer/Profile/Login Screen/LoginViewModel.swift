//
//  LoginViewModel.swift
//  BookPlayer
//
//  Created by gianni.carlo on 3/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import AuthenticationServices
import Foundation

class LoginViewModel: BaseViewModel<LoginCoordinator> {
  func handleSignIn(authorization: ASAuthorization) {
    switch authorization.credential {
    case let appleIDCredential as ASAuthorizationAppleIDCredential:

      // Create an account in your system.
      let userIdentifier = appleIDCredential.user
      // email won't be there on subsequent approvals
      // (save locally in case account creation fails for some reason)
      let email = appleIDCredential.email

      print(userIdentifier)
      print(email)

      // TODO: network call to create the user
      
    default:
      break
    }
  }

  func handleError(_ error: Error) {
    self.coordinator.showError(error)
  }
}
