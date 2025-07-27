//
//  SettingsViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 30/10/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation

class SettingsViewModel: ViewModelProtocol {
  /// Available routes
  enum Routes {
    case pro
    case themes
    case icons
  }

  enum Events {
    case showLoader(flag: Bool)
    case showAlert(content: BPAlertContent)
  }

  weak var coordinator: SettingsCoordinator!
  let accountService: AccountServiceProtocol
  let libraryService: LibraryServiceProtocol
  let syncService: SyncServiceProtocol
  let jellyfinConnectionService: JellyfinConnectionService

  var onTransition: BPTransition<Routes>?

  @Published var account: Account?

  private var disposeBag = Set<AnyCancellable>()
  var eventsPublisher = InterfaceUpdater<SettingsViewModel.Events>()

  init(
    accountService: AccountServiceProtocol,
    libraryService: LibraryServiceProtocol,
    syncService: SyncServiceProtocol,
    jellyfinConnectionService: JellyfinConnectionService
  ) {
    self.accountService = accountService
    self.libraryService = libraryService
    self.syncService = syncService
    self.jellyfinConnectionService = jellyfinConnectionService
    
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

  func observeEvents() -> AnyPublisher<SettingsViewModel.Events, Never> {
    eventsPublisher.eraseToAnyPublisher()
  }

  private func sendEvent(_ event: SettingsViewModel.Events) {
    eventsPublisher.send(event)
  }

  func reloadAccount() {
    self.account = self.accountService.getAccount()
  }

  func hasActiveSubscription() -> Bool {
    return accountService.hasSyncEnabled()
  }

  func hasMadeDonation() -> Bool {
    return accountService.hasPlusAccess()
  }

  func getAnonymousId() -> String {
    return accountService.getAnonymousId() ?? ""
  }

  func showPro() {
    onTransition?(.pro)
  }

  func showThemes() {
    onTransition?(.themes)
  }

  func showIcons() {
    onTransition?(.icons)
  }
}
