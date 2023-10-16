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

class LoginViewModel: ViewModelProtocol {
  enum Routes {
    case completeAccount
    case dismiss
  }

  var onTransition: BPTransition<Routes>?

  weak var coordinator: LoginCoordinator!
  let accountService: AccountServiceProtocol

  init(accountService: AccountServiceProtocol) {
    self.accountService = accountService
  }

  /// This should only be used when running the app in the simulator
  func setupTestAccount() {
    do {
      let token: String = Bundle.main.configurationValue(for: .mockedBearerToken)
      try self.accountService.loginTestAccount(token: token)
    } catch {
      self.coordinator.showError(error)
    }

    onTransition?(.completeAccount)
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
        await MainActor.run { [weak self] in
          self?.coordinator.showLoader()
        }

        do {
          let account = try await accountService.login(
            with: token,
            userId: appleIDCredential.user
          )

          await MainActor.run { [weak self, account] in
            self?.coordinator.stopLoader()

            if let account = account,
               !account.hasSubscription {
              self?.onTransition?(.completeAccount)
            } else {
              self?.onTransition?(.dismiss)
            }
          }
        } catch {
          await MainActor.run { [weak self, error] in
            self?.coordinator.stopLoader()
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
