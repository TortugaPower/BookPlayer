//
//  ProfileViewController.swift
//  BookPlayer
//
//  Created by gianni.carlo on 12/3/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import SwiftUI
import Themeable
import UIKit

class ProfileViewController: UIViewController {
  var viewModel: ProfileViewModel

  // MARK: - UI components

  private lazy var profileView: UIView = {
    let view = ProfileView(viewModel: viewModel)
    let hostingController = UIHostingController(rootView: view)
    hostingController.view.backgroundColor = .clear
    hostingController.view.isOpaque = false
    addChild(hostingController)
    hostingController.didMove(toParent: self)
    hostingController.view.translatesAutoresizingMaskIntoConstraints = false

    return hostingController.view
  }()

  private var disposeBag = Set<AnyCancellable>()

  // MARK: - Initializer

  init(viewModel: ProfileViewModel) {
    self.viewModel = viewModel
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()

    self.navigationItem.title = "profile_title".localized

    addSubviews()
    addConstraints()
    setUpTheming()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    viewModel.refreshSyncStatusMessage()
  }

  func addSubviews() {
    view.addSubview(profileView)
  }

  func addConstraints() {
    let safeLayoutGuide = view.safeAreaLayoutGuide

    NSLayoutConstraint.activate([
      profileView.topAnchor.constraint(equalTo: safeLayoutGuide.topAnchor),
      profileView.leadingAnchor.constraint(equalTo: safeLayoutGuide.leadingAnchor),
      profileView.trailingAnchor.constraint(equalTo: safeLayoutGuide.trailingAnchor),
      profileView.bottomAnchor.constraint(equalTo: safeLayoutGuide.bottomAnchor),
    ])
  }
}

// MARK: - Themeable

extension ProfileViewController: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    view.backgroundColor = theme.systemGroupedBackgroundColor

    self.overrideUserInterfaceStyle = theme.useDarkVariant
      ? UIUserInterfaceStyle.dark
      : UIUserInterfaceStyle.light
  }
}
