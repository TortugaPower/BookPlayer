//
//  JellyfinLibraryViewController.swift
//  BookPlayer
//
//  Created by Lysann Schlegel on 2024-10-26.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import JellyfinAPI
import SwiftUI
import Themeable
import UIKit

class JellyfinLibraryViewController: UIViewController, MVVMControllerProtocol {
  var viewModel: JellyfinLibraryViewModel!
  var apiClient: JellyfinClient!

  var selectedViewSubscriber: AnyCancellable?

  // MARK: - UI components

  private lazy var contentView: UIView = {
    let view = JellyfinLibraryView(viewModel: viewModel)
    let hostingController = UIHostingController(rootView: view)
    addChild(hostingController)
    hostingController.didMove(toParent: self)
    hostingController.view.translatesAutoresizingMaskIntoConstraints = false
    return hostingController.view
  }()

  // MARK: - Initializer

  init(viewModel: JellyfinLibraryViewModel, apiClient: JellyfinClient) {
    super.init(nibName: nil, bundle: nil)
    self.viewModel = viewModel
    self.apiClient = apiClient
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()

    addSubviews()
    addConstraints()
    setUpTheming()

    startLoadingContent()
  }

  private func addSubviews() {
    view.addSubview(contentView)
  }

  private func addConstraints() {
    let safeLayoutGuide = view.safeAreaLayoutGuide
    NSLayoutConstraint.activate([
      contentView.topAnchor.constraint(equalTo: safeLayoutGuide.topAnchor),
      contentView.leadingAnchor.constraint(equalTo: safeLayoutGuide.leadingAnchor),
      contentView.trailingAnchor.constraint(equalTo: safeLayoutGuide.trailingAnchor),
      contentView.bottomAnchor.constraint(equalTo: safeLayoutGuide.bottomAnchor),
    ])
  }

  // MARK: - Network

  private func startLoadingContent()
  {
    loadUserViews()
  }

  private func loadUserViews() {
    self.viewModel.userViews = []
    self.viewModel.selectedView = nil
    self.viewModel.items = []

    self.selectedViewSubscriber?.cancel()
    self.selectedViewSubscriber = nil

    let parameters = Paths.GetUserViewsParameters(presetViews: [.books])
    Task {
      let response = try await apiClient.send(Paths.getUserViews(parameters: parameters))
      let userViews = (response.value.items ?? []).filter { userView in
        return userView.collectionType == .books && userView.id != nil
      }
      self.viewModel.userViews = userViews.map { userView in
        JellyfinLibraryViewModel.UserView(id: userView.id!, name: userView.name ?? userView.id!)
      }

      self.selectedViewSubscriber?.cancel()
      self.selectedViewSubscriber = self.viewModel.$selectedView.sink { [weak self] selectedView in
        guard let self else {
          return
        }
        self.viewModel.items = []
        guard let selectedView else {
          return
        }
        self.loadItems(forUserView: selectedView)
      }
    }
  }

  private func loadItems(forUserView userView: JellyfinLibraryViewModel.UserView) {
    let parameters = Paths.GetItemsParameters(
      limit: 20,
      isRecursive: true,
      parentID: userView.id,
      includeItemTypes: [.audioBook]
    )
    Task {
      let response = try await apiClient.send(Paths.getItems(parameters: parameters))
      let items = (response.value.items ?? []).filter { item in
        return item.id != nil
      }
      self.viewModel.items = items.map { item in
        JellyfinLibraryViewModel.Item(id: item.id!, name: item.name ?? item.id!)
      }
    }
  }
}

// MARK: - Themeable

extension JellyfinLibraryViewController: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    contentView.backgroundColor = theme.systemGroupedBackgroundColor
  }
}
