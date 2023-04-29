//
//  ItemDetailsViewController.swift
//  BookPlayer
//
//  Created by gianni.carlo on 5/12/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import SwiftUI
import Themeable
import UIKit

class ItemDetailsViewController: BaseViewController<ItemDetailsCoordinator, ItemDetailsViewModel> {
  // MARK: - UI components

  private lazy var detailsView: UIView = {
    let view = ItemDetailsView(viewModel: viewModel.formViewModel)
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

  init(viewModel: ItemDetailsViewModel) {
    super.init(nibName: nil, bundle: nil)
    self.viewModel = viewModel
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

  func setupNavigationItem() {
    self.navigationItem.title = "Edit"
    self.navigationItem.leftBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .cancel,
      target: self,
      action: #selector(self.didTapCancel)
    )
    self.navigationItem.rightBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .save,
      target: self,
      action: #selector(self.didTapSave)
    )
  }

  func addSubviews() {
    view.addSubview(detailsView)
  }

  func addConstraints() {
    let safeLayoutGuide = view.safeAreaLayoutGuide

    NSLayoutConstraint.activate([
      detailsView.topAnchor.constraint(equalTo: safeLayoutGuide.topAnchor),
      detailsView.leadingAnchor.constraint(equalTo: safeLayoutGuide.leadingAnchor),
      detailsView.trailingAnchor.constraint(equalTo: safeLayoutGuide.trailingAnchor),
      detailsView.bottomAnchor.constraint(equalTo: safeLayoutGuide.bottomAnchor),
    ])
  }

  @objc func didTapCancel() {
    viewModel.handleCancelAction()
  }

  @objc func didTapSave() {
    viewModel.handleSaveAction()
  }
}

// MARK: - Themeable

extension ItemDetailsViewController: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    view.backgroundColor = theme.systemGroupedBackgroundColor

    self.overrideUserInterfaceStyle = theme.useDarkVariant
      ? UIUserInterfaceStyle.dark
      : UIUserInterfaceStyle.light
  }
}
