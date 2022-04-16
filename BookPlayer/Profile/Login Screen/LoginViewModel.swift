//
//  LoginViewModel.swift
//  BookPlayer
//
//  Created by gianni.carlo on 3/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import AuthenticationServices
import BookPlayerKit
import Foundation

class LoginViewModel: BaseViewModel<LoginCoordinator> {
  let accountService: AccountServiceProtocol

  init(accountService: AccountServiceProtocol) {
    self.accountService = accountService
  }

  func setupTestAccount() {
    self.accountService.updateAccount(
      id: "testId1234",
      email: "test@test.com",
      donationMade: nil,
      hasSubscription: nil,
      accessToken: nil
    )

    self.coordinator.showCompleteAccount()
  }

  func handleSignIn(authorization: ASAuthorization) {
    switch authorization.credential {
    case let appleIDCredential as ASAuthorizationAppleIDCredential:
      guard
        let tokenData = appleIDCredential.identityToken,
        let token = String(data: tokenData, encoding: .utf8)
      else {
        self.coordinator.showError(AccountError.missingToken)
        return
      }

      Task { [weak self, accountService, token, appleIDCredential] in
        do {
          try await accountService.login(
            with: token,
            userId: appleIDCredential.user
          )

          await MainActor.run { [weak self] in
            self?.coordinator.showCompleteAccount()
          }
        } catch {
          await MainActor.run { [weak self, error] in
            self?.coordinator.showError(error)
          }
        }
      }

    default:
      break
    }
  }

  func handleError(_ error: Error) {
    self.coordinator.showError(error)
  }
}
