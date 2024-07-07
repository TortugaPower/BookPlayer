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

protocol LoginViewModelProtocol: ObservableObject {
  func handleSignIn(authorization: ASAuthorization)
  func dismiss()
}

class LoginViewModel: LoginViewModelProtocol {
  enum Routes {
    case completeAccount
    case dismiss
  }

  var onTransition: BPTransition<Routes>?

  weak var alertPresenter: AlertPresenter!
  let accountService: AccountServiceProtocol

  init(accountService: AccountServiceProtocol) {
    self.accountService = accountService
  }

  /// This should only be used when running the app in the simulator
  func setupTestAccount() {
    Task {
      await MainActor.run { [weak self] in
        self?.alertPresenter.showLoader()
      }
      do {
        let token: String = Bundle.main.configurationValue(for: .mockedBearerToken)
        try await self.accountService.loginTestAccount(token: token)
        await MainActor.run { [weak self] in
          self?.alertPresenter.stopLoader()
        }
      } catch {
        await MainActor.run { [weak self, error] in
          self?.alertPresenter.stopLoader()
          self?.handleError(error)
        }
      }

      await MainActor.run { [weak self] in
        self?.onTransition?(.completeAccount)
      }
    }
  }

  func handleSignIn(authorization: ASAuthorization) {
    switch authorization.credential {
    case let appleIDCredential as ASAuthorizationAppleIDCredential:
      guard
        let tokenData = appleIDCredential.identityToken,
        let token = String(data: tokenData, encoding: .utf8)
      else {
        handleError(AccountError.missingToken)
        return
      }

      Task { [weak self, accountService, token, appleIDCredential] in
        await MainActor.run { [weak self] in
          self?.alertPresenter.showLoader()
        }

        do {
          let account = try await accountService.login(
            with: token,
            userId: appleIDCredential.user
          )

          await MainActor.run { [weak self, account] in
            self?.alertPresenter.stopLoader()

            if let account = account,
               !account.hasSubscription {
              self?.onTransition?(.completeAccount)
            } else {
              self?.onTransition?(.dismiss)
            }
          }
        } catch {
          await MainActor.run { [weak self, error] in
            self?.alertPresenter.stopLoader()
            self?.handleError(error)
          }
        }
      }

    default:
      break
    }
  }

  func handleError(_ error: Error) {
    alertPresenter.showAlert(
      "error_title".localized,
      message: error.localizedDescription,
      completion: nil
    )
  }

  func dismiss() {
    onTransition?(.dismiss)
  }
}
