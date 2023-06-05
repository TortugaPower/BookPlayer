//
//  CompleteAccountViewController.swift
//  BookPlayer
//
//  Created by gianni.carlo on 8/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import SwiftUI
import Themeable
import UIKit

class CompleteAccountViewController: BaseViewController<CompleteAccountCoordinator, CompleteAccountViewModel> {
  // MARK: - UI components

  private lazy var chooseLabel: UILabel = {
    let label = BaseLabel()
    label.font = Fonts.body
    label.text = "choose_plan_title".localized
    label.textAlignment = .center
    return label
  }()

  private lazy var pricingOptionsView: UIView = {
    let view = PricingOptionsView(viewModel: viewModel.pricingViewModel)
    let hostingController = UIHostingController(rootView: view)
    hostingController.view.backgroundColor = .clear
    hostingController.view.isOpaque = false
    addChild(hostingController)
    hostingController.didMove(toParent: self)
    hostingController.view.translatesAutoresizingMaskIntoConstraints = false

    return hostingController.view
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
    viewModel.loadPricingOptions()
  }

  func setupNavigationItem() {
    self.title = "BookPlayer Pro"
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
    view.addSubview(chooseLabel)
    view.addSubview(pricingOptionsView)
    view.addSubview(subscribeButton)
    view.addSubview(disclaimerTextView)
  }

  func addConstraints() {
    let safeLayoutGuide = view.safeAreaLayoutGuide

    NSLayoutConstraint.activate([
      chooseLabel.topAnchor.constraint(equalTo: safeLayoutGuide.topAnchor, constant: Spacing.M),
      chooseLabel.leadingAnchor.constraint(equalTo: safeLayoutGuide.leadingAnchor, constant: Spacing.M),
      chooseLabel.trailingAnchor.constraint(equalTo: safeLayoutGuide.trailingAnchor, constant: -Spacing.M),
      pricingOptionsView.topAnchor.constraint(equalTo: chooseLabel.bottomAnchor, constant: Spacing.S),
      pricingOptionsView.leadingAnchor.constraint(equalTo: safeLayoutGuide.leadingAnchor, constant: Spacing.M),
      pricingOptionsView.trailingAnchor.constraint(equalTo: safeLayoutGuide.trailingAnchor, constant: -Spacing.M),
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
    self.chooseLabel.textColor = theme.secondaryColor
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
