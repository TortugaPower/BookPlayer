//
//  IconsViewModel.swift
//  BookPlayer
//
//  Created by gianni.carlo on 11/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine

final class IconsViewModel {
  /// Available routes for this screen
  enum Routes {
    case showPro
  }

  /// Events that the screen can handle
  enum Events {
    case showAlert(content: BPAlertContent)
    case showLoader(Bool)
    case donationMade
  }

  let accountService: AccountServiceProtocol

  @Published var account: Account?

  var hasSubscription: Bool {
    return accountService.hasSyncEnabled()
  }

  /// Callback to handle actions on this screen
  public var onTransition: BPTransition<Routes>?
  /// Events publisher
  private var eventsPublisher = InterfaceUpdater<IconsViewModel.Events>()

  private var disposeBag = Set<AnyCancellable>()

  init(accountService: AccountServiceProtocol) {
    self.accountService = accountService

    self.reloadAccount()
    self.bindObservers()
  }

  func observeEvents() -> AnyPublisher<IconsViewModel.Events, Never> {
    eventsPublisher.eraseToAnyPublisher()
  }

  private func bindObservers() {
    NotificationCenter.default.publisher(for: .accountUpdate, object: nil)
      .sink(receiveValue: { [weak self] _ in
        self?.reloadAccount()
      })
      .store(in: &disposeBag)
  }

  private func sendEvent(_ event: IconsViewModel.Events) {
    eventsPublisher.send(event)
  }

  func reloadAccount() {
    self.account = self.accountService.getAccount()
  }

  func hasMadeDonation() -> Bool {
    return accountService.hasPlusAccess()
  }

  func showPro() {
    onTransition?(.showPro)
  }

  func handleRestorePurchases() {
    Task { @MainActor [weak self] in
      guard let self = self else { return }

      self.sendEvent(.showLoader(true))

      do {
        let customerInfo = try await self.accountService.restorePurchases()

        self.sendEvent(.showLoader(false))

        if customerInfo.nonSubscriptions.isEmpty {
          self.sendEvent(.showAlert(
            content: BPAlertContent(
              title: "tip_missing_title".localized,
              style: .alert,
              actionItems: [BPActionItem.okAction]
            )
          ))
        } else {
          self.accountService.updateAccount(
            id: nil,
            email: nil,
            donationMade: true,
            hasSubscription: nil
          )

          self.sendEvent(.showAlert(
            content: BPAlertContent(
              title: "purchases_restored_title".localized,
              style: .alert,
              actionItems: [BPActionItem.okAction]
            )
          ))

          self.sendEvent(.donationMade)
        }
      } catch {
        self.sendEvent(.showLoader(false))
        self.sendEvent(.showAlert(
          content: BPAlertContent.errorAlert(message: error.localizedDescription)
        ))
      }
    }
  }
}
