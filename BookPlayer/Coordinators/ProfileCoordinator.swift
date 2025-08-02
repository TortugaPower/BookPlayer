//
//  ProfileCoordinator.swift
//  BookPlayer
//
//  Created by gianni.carlo on 12/3/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import UIKit

class ProfileCoordinator: Coordinator {
  weak var tabBarController: UITabBarController?

  let flow: BPCoordinatorPresentationFlow
  let libraryService: LibraryServiceProtocol
  let playerManager: PlayerManagerProtocol
  let accountService: AccountServiceProtocol
  let syncService: SyncServiceProtocol

  init(
    flow: BPCoordinatorPresentationFlow,
    libraryService: LibraryServiceProtocol,
    playerManager: PlayerManagerProtocol,
    accountService: AccountServiceProtocol,
    syncService: SyncServiceProtocol
  ) {
    self.flow = flow
    self.libraryService = libraryService
    self.playerManager = playerManager
    self.accountService = accountService
    self.syncService = syncService
  }

  func start() {}

  func showAccount() {
    if self.accountService.getAccountId() != nil {
      let child = AccountCoordinator(
        flow: .modalFlow(presentingController: flow.navigationController),
        accountService: self.accountService
      )
      child.start()
    } else {
      let loginCoordinator = LoginCoordinator(
        flow: .modalFlow(presentingController: flow.navigationController),
        accountService: accountService
      )
      loginCoordinator.onFinish = { [unowned self] routes in
        switch routes {
        case .completeAccount:
          showCompleteAccount()
        }
      }
      loginCoordinator.start()
    }
  }

  func showQueuedTasks() {
  }

  func showCompleteAccount() {
    let coordinator = CompleteAccountCoordinator(
      flow: .modalFlow(presentingController: flow.navigationController, prefersMediumDetent: true),
      accountService: self.accountService
    )
    coordinator.start()
  }
}
