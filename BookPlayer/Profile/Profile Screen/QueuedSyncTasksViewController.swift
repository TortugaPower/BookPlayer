//
//  QueuedSyncTasksViewController.swift
//  BookPlayer
//
//  Created by gianni.carlo on 26/5/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import SwiftUI
import Themeable
import UIKit

class QueuedSyncTasksViewController: UIViewController {
  var viewModel: QueuedSyncTasksViewModel

  // MARK: - UI components

  private lazy var queuedTasksView: UIView = {
    let view = QueuedSyncTasksView(viewModel: viewModel)
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

  init(viewModel: QueuedSyncTasksViewModel) {
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

    self.navigationItem.title = "tasks_title".localized
    self.navigationItem.leftBarButtonItem = UIBarButtonItem(
      image: ImageIcons.navigationBackImage,
      style: .plain,
      target: self,
      action: #selector(self.didPressClose)
    )
    self.navigationItem.rightBarButtonItem = UIBarButtonItem(
      image: ImageIcons.info,
      style: .plain,
      target: self,
      action: #selector(self.didPressInfo)
    )

    addSubviews()
    addConstraints()
    setUpTheming()
    observeEvents()
  }

  func addSubviews() {
    view.addSubview(queuedTasksView)
  }

  func addConstraints() {
    let safeLayoutGuide = view.safeAreaLayoutGuide

    NSLayoutConstraint.activate([
      queuedTasksView.topAnchor.constraint(equalTo: safeLayoutGuide.topAnchor),
      queuedTasksView.leadingAnchor.constraint(equalTo: safeLayoutGuide.leadingAnchor),
      queuedTasksView.trailingAnchor.constraint(equalTo: safeLayoutGuide.trailingAnchor),
      queuedTasksView.bottomAnchor.constraint(equalTo: safeLayoutGuide.bottomAnchor),
    ])
  }

  func observeEvents() {
    self.viewModel.observeEvents()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] event in
        switch event {
        case .showAlert(let content):
          self?.showAlert(content)
        }
      }
      .store(in: &disposeBag)
  }

  override func accessibilityPerformEscape() -> Bool {
    self.dismiss(animated: true)
    return true
  }

  @objc func didPressClose() {
    self.dismiss(animated: true)
  }

  @objc func didPressInfo() {
    viewModel.showInfo()
  }
}

// MARK: - Themeable

extension QueuedSyncTasksViewController: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    view.backgroundColor = theme.systemGroupedBackgroundColor

    self.overrideUserInterfaceStyle = theme.useDarkVariant
    ? UIUserInterfaceStyle.dark
    : UIUserInterfaceStyle.light
  }
}
