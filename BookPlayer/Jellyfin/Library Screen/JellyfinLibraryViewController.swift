//
//  JellyfinLibraryViewController.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-10-26.
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

    setupNavigationItem()
    addSubviews()
    addConstraints()
    setUpTheming()
  }

  private func setupNavigationItem() {
    self.navigationItem.title = viewModel.libraryName
    self.navigationItem.leftBarButtonItem = UIBarButtonItem(
      title: "jellyfin_sign_out_button".localized,
      style: .plain,
      target: self,
      action: #selector(self.didTapSignOut)
    )
    self.navigationItem.rightBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .done,
      target: self,
      action: #selector(self.didTapDone)
    )
    definesPresentationContext = true
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

  @objc private func didTapSignOut() {
    viewModel.handleSignOutAction()
  }

  @objc private func didTapDone() {
    viewModel.handleDoneAction()
  }
}

// MARK: - Themeable

extension JellyfinLibraryViewController: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    contentView.backgroundColor = theme.systemGroupedBackgroundColor
  }
}
