//
//  LoginViewController.swift
//  BookPlayer
//
//  Created by gianni.carlo on 3/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import AuthenticationServices
import BookPlayerKit
import Foundation
import Themeable

class LoginViewController: UIViewController {
  var viewModel: LoginViewModel!
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

  private lazy var cloudBenefitStackView: UIStackView = {
    let stackView = LoginBenefitView(
      title: "benefits_cloudsync_title".localized,
      description: "benefits_cloudsync_description".localized,
      systemName: "icloud.and.arrow.up.fill",
      imageAlpha: 0.5
    )
    stackView.translatesAutoresizingMaskIntoConstraints = false
    return stackView
  }()

  private lazy var cosmeticBenefitStackView: UIStackView = {
    let stackView = LoginBenefitView(
      title: "benefits_themesicons_title".localized,
      description: "benefits_themesicons_description".localized,
      shouldAddOverlay: true,
      imageName: "BookPlayerPlus",
      imageAlpha: 0.5
    )
    stackView.translatesAutoresizingMaskIntoConstraints = false
    return stackView
  }()

  private lazy var supportBenefitStackView: UIStackView = {
    let stackView = LoginBenefitView(
      title: "benefits_supportus_title".localized,
      description: "benefits_supportus_description".localized,
      imageName: "plusImageSupport"
    )
    stackView.translatesAutoresizingMaskIntoConstraints = false
    return stackView
  }()

  private lazy var disclaimerStackView: UIStackView = {
    let stackView = LoginDisclaimerView(
      title: "benefits_disclaimer_title".localized,
      disclaimers: [
        "benefits_disclaimer_account_description".localized,
        "benefits_disclaimer_subscription_description".localized,
        "benefits_disclaimer_watch_description".localized
      ]
    )
    stackView.translatesAutoresizingMaskIntoConstraints = false
    return stackView
  }()

  private lazy var loginProviderStackView: UIStackView = {
    let stackView = UIStackView()
    stackView.translatesAutoresizingMaskIntoConstraints = false
    return stackView
  }()

  // MARK: - Initializer

  init(viewModel: LoginViewModel) {
    super.init(nibName: nil, bundle: nil)
    self.viewModel = viewModel
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()

    self.title = "BookPlayer Pro"

    self.navigationItem.leftBarButtonItem = UIBarButtonItem(
      image: ImageIcons.navigationBackImage,
      style: .plain,
      target: self,
      action: #selector(self.didPressClose)
    )

    addSubviews()
    addConstraints()

    setUpTheming()
  }

  func addSubviews() {
    view.addSubview(loginProviderStackView)
    view.addSubview(scrollView)
    scrollView.addSubview(contentView)
    contentView.addSubview(cloudBenefitStackView)
    contentView.addSubview(cosmeticBenefitStackView)
    contentView.addSubview(supportBenefitStackView)
    contentView.addSubview(disclaimerStackView)
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
      scrollView.bottomAnchor.constraint(equalTo: loginProviderStackView.topAnchor, constant: -Spacing.S),
      contentView.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor),
      contentView.leadingAnchor.constraint(equalTo: contentLayoutGuide.leadingAnchor),
      contentView.trailingAnchor.constraint(equalTo: contentLayoutGuide.trailingAnchor),
      contentView.bottomAnchor.constraint(equalTo: contentLayoutGuide.bottomAnchor),
      contentView.widthAnchor.constraint(equalTo: view.widthAnchor),
      // setup button container
      loginProviderStackView.heightAnchor.constraint(equalToConstant: 45),
      loginProviderStackView.leadingAnchor.constraint(equalTo: safeLayoutGuide.leadingAnchor, constant: Spacing.M),
      loginProviderStackView.trailingAnchor.constraint(equalTo: safeLayoutGuide.trailingAnchor, constant: -Spacing.M),
      loginProviderStackView.bottomAnchor.constraint(equalTo: safeLayoutGuide.bottomAnchor, constant: -Spacing.S),
      // setup benefits
      cloudBenefitStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Spacing.M),
      cloudBenefitStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      cloudBenefitStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Spacing.M),
      cosmeticBenefitStackView.topAnchor.constraint(equalTo: cloudBenefitStackView.bottomAnchor, constant: 30),
      cosmeticBenefitStackView.leadingAnchor.constraint(equalTo: cloudBenefitStackView.leadingAnchor),
      cosmeticBenefitStackView.trailingAnchor.constraint(equalTo: cloudBenefitStackView.trailingAnchor),
      supportBenefitStackView.topAnchor.constraint(equalTo: cosmeticBenefitStackView.bottomAnchor, constant: 30),
      supportBenefitStackView.leadingAnchor.constraint(equalTo: cosmeticBenefitStackView.leadingAnchor),
      supportBenefitStackView.trailingAnchor.constraint(equalTo: cosmeticBenefitStackView.trailingAnchor),
      // setup disclaimer
      disclaimerStackView.topAnchor.constraint(
        greaterThanOrEqualTo: supportBenefitStackView.bottomAnchor,
        constant: 45
      ),
      disclaimerStackView.leadingAnchor.constraint(equalTo: supportBenefitStackView.leadingAnchor, constant: Spacing.M),
      disclaimerStackView.trailingAnchor.constraint(equalTo: supportBenefitStackView.trailingAnchor),
      disclaimerStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Spacing.L),
    ])
  }

  func setupProviderLoginView(_ useDarkVariant: Bool) {
    self.loginProviderStackView.arrangedSubviews.forEach({
      self.loginProviderStackView.removeArrangedSubview($0)
    })

    let style: ASAuthorizationAppleIDButton.Style = useDarkVariant ? .white : .black

    let authorizationButton = ASAuthorizationAppleIDButton(type: .signIn, style: style)
    authorizationButton.addTarget(self, action: #selector(handleAuthorizationAppleIDButtonPress), for: .touchUpInside)
    self.loginProviderStackView.addArrangedSubview(authorizationButton)
  }

  // MARK: - Actions

  @objc func handleAuthorizationAppleIDButtonPress() {
#if DEBUG
    self.viewModel.setupTestAccount()
#else
    let appleIDProvider = ASAuthorizationAppleIDProvider()
    let request = appleIDProvider.createRequest()
    request.requestedScopes = [.email]

    let authorizationController = ASAuthorizationController(authorizationRequests: [request])
    authorizationController.delegate = self
    authorizationController.presentationContextProvider = self
    authorizationController.performRequests()
#endif
  }

  @objc private func didPressClose() {
    self.viewModel.dismiss()
  }
}

// MARK: - Sign in with Apple Delegate

extension LoginViewController: ASAuthorizationControllerDelegate {
  /// - Tag: did_complete_authorization
  func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
    self.viewModel.handleSignIn(authorization: authorization)
  }

  func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
    self.viewModel.handleError(error)
  }
}

extension LoginViewController: ASAuthorizationControllerPresentationContextProviding {
  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    return self.view.window!
  }
}

// MARK: - Themeable

extension LoginViewController: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    self.view.backgroundColor = theme.systemBackgroundColor

    self.overrideUserInterfaceStyle = theme.useDarkVariant
    ? UIUserInterfaceStyle.dark
    : UIUserInterfaceStyle.light

    self.setupProviderLoginView(theme.useDarkVariant)
  }
}
