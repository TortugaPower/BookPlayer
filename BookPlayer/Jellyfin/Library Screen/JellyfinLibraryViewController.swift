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
  let apiClient: JellyfinClient

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
    self.viewModel = viewModel
    self.apiClient = apiClient
    super.init(nibName: nil, bundle: nil)
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

    let parameters = Paths.GetUserViewsParameters(presetViews: [.books])
    Task {
      let response = try await apiClient.send(Paths.getUserViews(parameters: parameters))
      let userViews = (response.value.items ?? [])
        .compactMap { userView -> JellyfinLibraryItem? in
          guard userView.collectionType == .books, let id = userView.id else {
            return nil
          }
          let name = userView.name ?? userView.id!
          return JellyfinLibraryItem(id: id, name: name, kind: .userView)
        }
      { @MainActor in
        self.viewModel.userViews = userViews
      }()
    }
  }
}

// MARK: - Themeable

extension JellyfinLibraryViewController: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    contentView.backgroundColor = theme.systemGroupedBackgroundColor
  }
}
