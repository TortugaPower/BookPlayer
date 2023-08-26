//
//  AccountViewModel.swift
//  BookPlayer
//
//  Created by gianni.carlo on 8/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation
import BookPlayerKit
import Combine
import RevenueCat

class AccountViewModel: BaseViewModel<AccountCoordinator> {
  let accountService: AccountServiceProtocol

  @Published var account: Account?

  private var disposeBag = Set<AnyCancellable>()

  init(accountService: AccountServiceProtocol) {
    self.accountService = accountService

    super.init()

    self.reloadAccount()
    self.bindObservers()
  }

  func bindObservers() {
    NotificationCenter.default.publisher(for: .accountUpdate, object: nil)
      .sink(receiveValue: { [weak self] _ in
        self?.reloadAccount()
      })
      .store(in: &disposeBag)
  }

  func reloadAccount() {
    self.account = self.accountService.getAccount()
  }

  func showCompleteAccount() {
    self.coordinator.showCompleteAccount()
  }

  func hasSubscription() -> Bool {
    return self.account?.hasSubscription ?? false
  }

  func showManageSubscription() {
    guard !ProcessInfo.processInfo.isiOSAppOnMac else {
      self.coordinator.showError(AccountError.managementUnavailable)
      return
    }

    Purchases.shared.showManageSubscriptions { _ in }
  }

  func showTermsAndConditions() {
    guard
      let url = URL(string: "https://github.com/TortugaPower/BookPlayer/blob/main/TERMS_CONDITIONS.md")
    else { return }

    UIApplication.shared.open(url)
  }

  func showPrivacyPolicy() {
    guard
      let url = URL(string: "https://github.com/TortugaPower/BookPlayer/blob/main/PRIVACY_POLICY.md")
    else { return }

    UIApplication.shared.open(url)
  }

  func showManageFiles() {
    self.coordinator.showUploadedFiles()
  }

  func handleLogout() {
    do {
      try self.accountService.logout()
      self.dismiss()
    } catch {
      self.coordinator.showError(error)
    }
  }

  func showDeleteAlert() {
    self.coordinator.showDeleteAccountAlert { [weak self] in
      self?.handleDelete()
    }
  }

  func handleDelete() {
    Task { [weak self, accountService] in
      await MainActor.run { [weak self] in
        self?.coordinator.showLoader()
      }

      do {
        let result = try await accountService.deleteAccount()

        await MainActor.run { [weak self, result] in
          self?.coordinator.stopLoader()

          self?.coordinator.showAlert(result, message: nil, completion: {
            self?.dismiss()
          })
        }
      } catch {
        await MainActor.run { [weak self, error] in
          self?.coordinator.stopLoader()
          self?.coordinator.showError(error)
        }
      }
    }
  }
}
