//
//  ItemDetailsCoordinator.swift
//  BookPlayer
//
//  Created by gianni.carlo on 5/12/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import SwiftUI
import UIKit

class ItemDetailsCoordinator: Coordinator {
  /// Routes for this coordinator
  public enum Routes {
    case infoUpdated
  }
  /// Item being modified
  let item: SimpleLibraryItem
  /// Library service used for modifications
  let libraryService: LibraryServiceProtocol
  /// Service to sync new artwork
  let syncService: SyncServiceProtocol
  /// Weak reference to the navigation used to show the flow
  weak var flowNav: UINavigationController?
  /// Callback when the coordinator is done
  public var onFinish: ((Routes) -> Void)?

  /// Initializer
  init(
    item: SimpleLibraryItem,
    libraryService: LibraryServiceProtocol,
    syncService: SyncServiceProtocol,
    navigationController: UINavigationController
  ) {
    self.item = item
    self.libraryService = libraryService
    self.syncService = syncService

    super.init(
      navigationController: navigationController,
      flowType: .modal
    )
  }

  override func start() {
    let viewModel = ItemDetailsViewModel(
      item: item,
      libraryService: libraryService,
      syncService: syncService
    )
    viewModel.onTransition = { route in
      switch route {
      case .done:
        self.onFinish?(.infoUpdated)
      case .cancel:
        /// do nothing on cancel
        break
      }
      self.flowNav?.dismiss(animated: true)
    }
    let vc = ItemDetailsViewController(viewModel: viewModel)
    let nav = AppNavigationController.instantiate(from: .Main)
    nav.viewControllers = [vc]
    flowNav = nav

    navigationController.present(nav, animated: true)
  }
}
