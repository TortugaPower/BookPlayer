//
//  ProfileViewController.swift
//  BookPlayer
//
//  Created by gianni.carlo on 12/3/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import Themeable
import UIKit

class ProfileViewController: BaseViewController<ProfileCoordinator, ProfileViewModel> {
  // MARK: - UI components

  private lazy var scrollView: UIScrollView = {
    let scrollView = UIScrollView()
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    return scrollView
  }()

  private lazy var contentView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()

  private lazy var containerStackview: UIStackView = {
    let stackview = UIStackView()
    stackview.translatesAutoresizingMaskIntoConstraints = false
    stackview.axis = .vertical
    stackview.spacing = Spacing.S
    return stackview
  }()

  private lazy var profileCardView: ProfileCardView = {
    let cardView = ProfileCardView()

    cardView.tapAction = { [weak self] in
      self?.didTapAccount()
    }

    return cardView
  }()

  private var disposeBag = Set<AnyCancellable>()

  // MARK: - Initializer

  init() {
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()

    self.navigationItem.title = "Profile"

    self.bindObservers()
    addSubviews()
    addConstraints()
    setUpTheming()
  }

  func addSubviews() {
    view.addSubview(scrollView)
    scrollView.addSubview(contentView)
    contentView.addSubview(containerStackview)
    containerStackview.addArrangedSubview(profileCardView)
  }

  func addConstraints() {
    let safeLayoutGuide = view.safeAreaLayoutGuide
    // constrain subviews to the scroll view's Content Layout Guide
    let contentLayoutGuide = scrollView.contentLayoutGuide

    NSLayoutConstraint.activate([
      // setup scrollview
      scrollView.topAnchor.constraint(equalTo: safeLayoutGuide.topAnchor),
      scrollView.leadingAnchor.constraint(equalTo: safeLayoutGuide.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: safeLayoutGuide.trailingAnchor),
      scrollView.bottomAnchor.constraint(equalTo: safeLayoutGuide.bottomAnchor),
      contentView.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor),
      contentView.leadingAnchor.constraint(equalTo: contentLayoutGuide.leadingAnchor),
      contentView.trailingAnchor.constraint(equalTo: contentLayoutGuide.trailingAnchor),
      contentView.bottomAnchor.constraint(equalTo: contentLayoutGuide.bottomAnchor),
      contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
      // setup contents
      containerStackview.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Spacing.S),
      containerStackview.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Spacing.S),
      containerStackview.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Spacing.S),
      containerStackview.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Spacing.M),
    ])
  }

  func bindObservers() {
    self.viewModel.$account
      .receive(on: RunLoop.main)
      .sink { [weak self] account in
      self?.setupProfileCardView(account)
    }
    .store(in: &disposeBag)
  }

  func setupProfileCardView(_ account: Account?) {
    if let account = account,
       !account.id.isEmpty {
      self.profileCardView.setup(title: account.email, status: nil)
    } else {
      self.profileCardView.setup(title: "Set Up Account", status: "Not signed in")
    }
  }

  func didTapAccount() {
    self.viewModel.showAccount()
  }
}

// MARK: - Themeable

extension ProfileViewController: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    view.backgroundColor = theme.systemBackgroundColor

    self.overrideUserInterfaceStyle = theme.useDarkVariant
      ? UIUserInterfaceStyle.dark
      : UIUserInterfaceStyle.light
  }
}
