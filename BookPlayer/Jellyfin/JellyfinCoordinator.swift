//
//  JellyfinCoordinator.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-10-26.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation
import JellyfinAPI
import SwiftUI
import UIKit

class JellyfinCoordinator: Coordinator, AlertPresenter {
  let flow: BPCoordinatorPresentationFlow
  private let singleFileDownloadService: SingleFileDownloadService
  private let connectionService: JellyfinConnectionService
  private var disposeBag = Set<AnyCancellable>()
  private var dismissing = false

  init(
    flow: BPCoordinatorPresentationFlow,
    singleFileDownloadService: SingleFileDownloadService,
    connectionService: JellyfinConnectionService
  ) {
    self.flow = flow
    self.singleFileDownloadService = singleFileDownloadService
    self.connectionService = connectionService

    bindObservers()
  }

  func bindObservers() {
    singleFileDownloadService.eventsPublisher.sink { [weak self] event in
      switch event {
      case .starting, .error:
        // Currently we only show the download issues or progress in the main view
        // So we hide the jellyfin views when download starts or has an error
        Task { @MainActor [weak self] in
          if let self, !self.dismissing {
            self.dismissing = true
            self.flow.finishPresentation(animated: true)
          }
        }
      default:
        break
      }
    }
    .store(in: &disposeBag)
  }

  func start() {
    let connectionVC = createJellyfinLoginScreen()
    flow.startPresentation(connectionVC, animated: true)

    tryShowLibraryView()
  }

  private func createJellyfinLoginScreen() -> UIViewController {
    let viewModel = JellyfinConnectionViewModel(connectionService: connectionService)

    viewModel.onTransition = { route in
      switch route {
      case .cancel:
        self.flow.finishPresentation(animated: true)
      case .signOut:
        break
      case .showLibrary:
        self.tryShowLibraryView()
      }
    }

    return UIHostingController(rootView: JellyfinConnectionView(viewModel: viewModel))
  }

  private func tryShowLibraryView() {
    guard
      let connectionData = connectionService.connection
    else {
      return
    }

    let viewModel = JellyfinLibraryViewModel(
      data: .topLevel(
        libraryName: connectionData.serverName,
        userID: connectionData.userID
      ),
      connectionService: connectionService,
      singleFileDownloadService: singleFileDownloadService
    )

    viewModel.onTransition = { route in
      switch route {
      case .done:
        self.flow.navigationController.dismiss(animated: true)
      case .showAlert(let content):
        self.showAlert(content)
      }
    }

    let vc = UIHostingController(rootView: JellyfinLibraryView(viewModel: viewModel))

    flow.pushViewController(vc, animated: true)
  }
}
