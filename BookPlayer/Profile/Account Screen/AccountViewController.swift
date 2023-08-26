//
//  AccountViewController.swift
//  BookPlayer
//
//  Created by gianni.carlo on 8/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import Themeable
import UIKit

class AccountViewController: BaseViewController<AccountCoordinator, AccountViewModel> {
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

  private lazy var accountSectionView: UIView = {
    return AccountSectionContainerView(
      contents: AccountCardView(title: viewModel.account?.email),
      insets: UIEdgeInsets(
        top: Spacing.S,
        left: Spacing.S,
        bottom: Spacing.S,
        right: Spacing.S
      )
    )
  }()

  private lazy var manageProSectionView: UIView = {
    let row = AccountRowContainerView(
      title: "BookPlayer Pro",
      systemImageName: "icloud.and.arrow.up.fill",
      detail: "manage_title".localized,
      showChevron: true,
      titleFont: Fonts.title
    )

    row.tapAction = { [weak self] in
      self?.didPressManageSubscription()
    }

    return AccountSectionContainerView(
      contents: row,
      insets: UIEdgeInsets(
        top: 0,
        left: Spacing.S,
        bottom: 0,
        right: Spacing.S
      )
    )
  }()

  private lazy var privacyPolicySectionView: UIView = {
    let row = AccountRowContainerView(
      title: "privacy_policy_title".localized,
      systemImageName: "doc.text"
    )

    row.tapAction = { [weak self] in
      self?.viewModel.showPrivacyPolicy()
    }

    return AccountSectionContainerView(
      contents: row,
      insets: UIEdgeInsets(
        top: 0,
        left: Spacing.S,
        bottom: 0,
        right: Spacing.S
      ),
      hideBottomSeparator: true
    )
  }()

  private lazy var termsSectionView: UIView = {
    let row = AccountRowContainerView(
      title: "terms_conditions_title".localized,
      systemImageName: "doc.text"
    )

    row.tapAction = { [weak self] in
      self?.viewModel.showTermsAndConditions()
    }

    return AccountSectionContainerView(
      contents: row,
      insets: UIEdgeInsets(
        top: 0,
        left: Spacing.S,
        bottom: 0,
        right: Spacing.S
      )
    )
  }()

  // TODO: add section about uploaded files
  private lazy var manageFilesSectionView: UIView = {
    // TODO: Add localization
    let row = AccountRowContainerView(
      title: "Uploaded Files",
      systemImageName: "folder",
      showChevron: true,
      titleFont: Fonts.title
    )

    row.tapAction = { [weak self] in
      self?.didPressManageFiles()
    }

    return AccountSectionContainerView(
      contents: row,
      insets: UIEdgeInsets(
        top: 0,
        left: Spacing.S,
        bottom: 0,
        right: Spacing.S
      )
    )
  }()

  private lazy var benefitsSectionView: UIView = {
    let row = AccountProBenefitsView()

    row.tapAction = { [weak self] in
      self?.didPressCompleteAccount()
    }

    return AccountSectionContainerView(
      contents: row,
      insets: UIEdgeInsets(
        top: Spacing.S,
        left: Spacing.S,
        bottom: Spacing.S,
        right: Spacing.S
      )
    )
  }()

  private lazy var logoutSectionView: UIView = {
    let imageName: String
    var flipImage = false

    if #available(iOS 15, *) {
      imageName = "rectangle.portrait.and.arrow.right"
    } else {
      imageName = "square.and.arrow.up"
      flipImage = true
    }

    let row = AccountRowContainerView(
      title: "logout_title".localized,
      systemImageName: imageName,
      flipImage: flipImage,
      imageTintColor: .red
    )

    row.tapAction = { [weak self] in
      self?.didPressLogout()
    }

    return AccountSectionContainerView(
      contents: row,
      insets: UIEdgeInsets(
        top: 0,
        left: Spacing.S,
        bottom: 0,
        right: Spacing.S
      )
    )
  }()

  private lazy var deleteSectionView: UIView = {
    let row = AccountRowContainerView(
      title: "delete_account_title".localized,
      systemImageName: "trash",
      imageTintColor: .red
    )

    row.tapAction = { [weak self] in
      self?.didPressDelete()
    }

    return AccountSectionContainerView(
      contents: row,
      insets: UIEdgeInsets(
        top: 0,
        left: Spacing.S,
        bottom: 0,
        right: Spacing.S
      )
    )
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

    setupNavigationItem()
    addSubviews()
    addConstraints()
    bindObservers()
    setUpTheming()
  }

  func setupNavigationItem() {
    self.navigationItem.title = "account_title".localized
    self.navigationItem.leftBarButtonItem = UIBarButtonItem(
      image: ImageIcons.navigationBackImage,
      style: .plain,
      target: self,
      action: #selector(self.didPressClose)
    )
  }

  func addSubviews() {
    view.addSubview(scrollView)
    scrollView.addSubview(contentView)
    contentView.addSubview(containerStackview)
    containerStackview.addArrangedSubview(accountSectionView)
    containerStackview.addArrangedSubview(manageProSectionView)
    containerStackview.addArrangedSubview(benefitsSectionView)
    containerStackview.addArrangedSubview(privacyPolicySectionView)
    containerStackview.addArrangedSubview(termsSectionView)
    containerStackview.setCustomSpacing(0, after: privacyPolicySectionView)
    containerStackview.setCustomSpacing(Spacing.S, after: benefitsSectionView)
    containerStackview.addArrangedSubview(logoutSectionView)
    containerStackview.addArrangedSubview(deleteSectionView)
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
      contentView.widthAnchor.constraint(equalTo: view.widthAnchor),
      // setup contents
      containerStackview.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Spacing.S),
      containerStackview.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      containerStackview.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      containerStackview.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Spacing.M),
    ])
  }

  func bindObservers() {
    self.viewModel.$account
      .receive(on: RunLoop.main)
      .sink { [weak self] account in
        if account?.hasSubscription == true {
          self?.benefitsSectionView.isHidden = true
          self?.manageProSectionView.isHidden = false
          self?.manageFilesSectionView.isHidden = false
        } else {
          self?.benefitsSectionView.isHidden = false
          self?.manageProSectionView.isHidden = true
          self?.manageFilesSectionView.isHidden = true
        }
      }
      .store(in: &disposeBag)
  }

  func didPressManageSubscription() {
    self.viewModel.showManageSubscription()
  }

  func didPressManageFiles() {
    self.viewModel.showManageFiles()
  }

  @objc func didPressCompleteAccount() {
    self.viewModel.showCompleteAccount()
  }

  func didPressLogout() {
    self.viewModel.handleLogout()
  }

  func didPressDelete() {
    self.viewModel.showDeleteAlert()
  }

  @objc func didPressClose() {
    self.viewModel.dismiss()
  }
}

// MARK: - Themeable

extension AccountViewController: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    view.backgroundColor = theme.secondarySystemBackgroundColor

    self.overrideUserInterfaceStyle = theme.useDarkVariant
    ? UIUserInterfaceStyle.dark
    : UIUserInterfaceStyle.light
  }
}
