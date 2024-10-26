//
//  JellyfinLibraryViewController.swift
//  BookPlayer
//
//  Created by Lysann Schlegel on 2024-10-26.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import JellyfinAPI
import SwiftUI
import Themeable
import UIKit

class JellyfinLibraryViewController: UIViewController, MVVMControllerProtocol {
  var viewModel: JellyfinLibraryViewModel!
  var apiClient: JellyfinClient!

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
}

// MARK: - Themeable

extension JellyfinLibraryViewController: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    contentView.backgroundColor = theme.systemGroupedBackgroundColor
  }
}
