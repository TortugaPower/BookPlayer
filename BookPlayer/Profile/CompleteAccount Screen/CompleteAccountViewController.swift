//
//  CompleteAccountViewController.swift
//  BookPlayer
//
//  Created by gianni.carlo on 8/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Themeable
import UIKit

class CompleteAccountViewController: BaseViewController<CompleteAccountCoordinator, CompleteAccountViewModel> {
  // MARK: - UI components

  private lazy var containerImageView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.layer.masksToBounds = true
    view.layer.cornerRadius = self.viewModel.containerImageWidth / 2
    return view
  }()

  private lazy var imageView: UIImageView = {
    let imageView = UIImageView(image: UIImage(systemName: "person.badge.plus"))
    imageView.translatesAutoresizingMaskIntoConstraints = false
    return imageView
  }()

  private lazy var emailLabel: UILabel = {
    let label = BaseLabel()
    label.text = self.viewModel.account.email
    label.font = Fonts.titleRegular
    return label
  }()

  private lazy var proLabel: UILabel = {
    let label = BaseLabel()
    label.text = "BookPlayer Pro"
    label.font = Fonts.body
    return label
  }()

  private lazy var costLabel: UILabel = {
    let label = BaseLabel()
    // TODO: localize
    label.text = "$4.99 / month"
    label.font = Fonts.title
    return label
  }()

  private lazy var monthlyLabel: UILabel = {
    let label = BaseLabel()
    label.font = Fonts.body
    label.text = "renewal_description".localized
    return label
  }()

  private lazy var subscribeButton: UIButton = {
    let button = FormButton(title: "subscribe_title".localized)
    button.addTarget(
      self,
      action: #selector(self.didPressSubscribe),
      for: .touchUpInside
    )
    return button
  }()

  private lazy var privacyPolicy = NSMutableAttributedString(
    string: "privacy_policy_title".localized,
    attributes: [
      .link: URL(string: "https://github.com/TortugaPower/BookPlayer/blob/main/PRIVACY_POLICY.md")!
    ]
  )

  private lazy var terms = NSMutableAttributedString(
    string: "terms_conditions_title".localized,
    attributes: [
      .link: URL(string: "https://github.com/TortugaPower/BookPlayer/blob/main/TERMS_CONDITIONS.md")!
    ]
  )

  private lazy var disclaimerTextView: UITextView = {
    let textView = UITextView()
    textView.delegate = self
    textView.showsVerticalScrollIndicator = false
    textView.bounces = false

    var finalString = NSMutableAttributedString(string: "\("agreement_prefix_title".localized) ")
    finalString.append(privacyPolicy)
    finalString.append(NSAttributedString(string: " \("and_title".localized) "))
    finalString.append(terms)
    textView.attributedText = finalString
    textView.font = Fonts.body
    textView.textAlignment = .center

    textView.translatesAutoresizingMaskIntoConstraints = false
    textView.adjustsFontForContentSizeCategory = true

    return textView
  }()

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
    setUpTheming()
  }

  func setupNavigationItem() {
    self.title = "completeaccount_title".localized
    self.navigationItem.leftBarButtonItem = UIBarButtonItem(
      image: ImageIcons.navigationBackImage,
      style: .plain,
      target: self,
      action: #selector(self.didPressClose)
    )
    self.navigationItem.rightBarButtonItem = UIBarButtonItem(
      title: "restore_title".localized,
      style: .plain,
      target: self,
      action: #selector(self.didPressRestore)
    )
  }

  func addSubviews() {
    containerImageView.addSubview(imageView)
    view.addSubview(containerImageView)
    view.addSubview(emailLabel)
    view.addSubview(proLabel)
    view.addSubview(costLabel)
    view.addSubview(monthlyLabel)
    view.addSubview(subscribeButton)
    view.addSubview(disclaimerTextView)
  }

  func addConstraints() {
    let safeLayoutGuide = view.safeAreaLayoutGuide

    NSLayoutConstraint.activate([
      imageView.widthAnchor.constraint(equalToConstant: viewModel.imageWidth),
      imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor),
      imageView.centerXAnchor.constraint(equalTo: containerImageView.centerXAnchor),
      imageView.centerYAnchor.constraint(equalTo: containerImageView.centerYAnchor),
      containerImageView.widthAnchor.constraint(equalToConstant: viewModel.containerImageWidth),
      containerImageView.heightAnchor.constraint(equalTo: containerImageView.widthAnchor),
      containerImageView.topAnchor.constraint(equalTo: safeLayoutGuide.topAnchor, constant: Spacing.M),
      containerImageView.centerXAnchor.constraint(equalTo: safeLayoutGuide.centerXAnchor),
      emailLabel.topAnchor.constraint(equalTo: containerImageView.bottomAnchor, constant: Spacing.S),
      emailLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      proLabel.topAnchor.constraint(equalTo: emailLabel.bottomAnchor, constant: Spacing.S2),
      proLabel.centerXAnchor.constraint(equalTo: safeLayoutGuide.centerXAnchor),
      costLabel.topAnchor.constraint(equalTo: proLabel.bottomAnchor, constant: Spacing.L),
      costLabel.centerXAnchor.constraint(equalTo: safeLayoutGuide.centerXAnchor),
      monthlyLabel.topAnchor.constraint(equalTo: costLabel.bottomAnchor, constant: Spacing.L),
      monthlyLabel.centerXAnchor.constraint(equalTo: safeLayoutGuide.centerXAnchor),
      subscribeButton.bottomAnchor.constraint(equalTo: disclaimerTextView.topAnchor, constant: -Spacing.S2),
      subscribeButton.leadingAnchor.constraint(equalTo: safeLayoutGuide.leadingAnchor, constant: Spacing.M),
      subscribeButton.trailingAnchor.constraint(equalTo: safeLayoutGuide.trailingAnchor, constant: -Spacing.M),
      disclaimerTextView.bottomAnchor.constraint(equalTo: safeLayoutGuide.bottomAnchor, constant: -Spacing.S),
      disclaimerTextView.heightAnchor.constraint(equalToConstant: 48),
      disclaimerTextView.leadingAnchor.constraint(equalTo: safeLayoutGuide.leadingAnchor, constant: Spacing.M),
      disclaimerTextView.trailingAnchor.constraint(equalTo: safeLayoutGuide.trailingAnchor, constant: -Spacing.M),
    ])
  }

  // MARK: - Actions

  @objc func didPressSubscribe() {
    self.viewModel.handleSubscription()
  }

  @objc func didPressClose() {
    self.viewModel.dismiss()
  }

  @objc func didPressRestore() {
    self.viewModel.handleRestorePurchases()
  }
}

// MARK: - Themeable

extension CompleteAccountViewController: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    self.view.backgroundColor = theme.systemBackgroundColor
    self.imageView.tintColor = theme.linkColor
    self.containerImageView.backgroundColor = theme.tertiarySystemBackgroundColor
    self.emailLabel.textColor = theme.primaryColor
    self.proLabel.textColor = theme.secondaryColor
    self.costLabel.textColor = theme.primaryColor
    self.monthlyLabel.textColor = theme.secondaryColor
    self.disclaimerTextView.backgroundColor = .clear
    self.disclaimerTextView.textColor = theme.primaryColor
    self.disclaimerTextView.linkTextAttributes = [
      .foregroundColor: theme.linkColor
    ]

    self.overrideUserInterfaceStyle = theme.useDarkVariant
      ? UIUserInterfaceStyle.dark
      : UIUserInterfaceStyle.light
  }
}

extension CompleteAccountViewController: UITextViewDelegate {
  func textView(
    _ textView: UITextView,
    shouldInteractWith URL: URL,
    in characterRange: NSRange,
    interaction: UITextItemInteraction
  ) -> Bool {
    viewModel.openLink(URL)
    return false
  }

  func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
    return false
  }
}
