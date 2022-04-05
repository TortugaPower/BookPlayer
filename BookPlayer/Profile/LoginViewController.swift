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

class LoginViewController: BaseViewController<LoginCoordinator, LoginViewModel>,
                           Storyboarded {
  @IBOutlet weak var loginProviderStackView: UIStackView!

  override func viewDidLoad() {
    super.viewDidLoad()

    self.title = "Set Up Account"
//    self.navigationController?.setNavigationBarHidden(true, animated: false)

    setUpTheming()
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

  @objc
  func handleAuthorizationAppleIDButtonPress() {
    let appleIDProvider = ASAuthorizationAppleIDProvider()
    let request = appleIDProvider.createRequest()
    request.requestedScopes = [.email]

    let authorizationController = ASAuthorizationController(authorizationRequests: [request])
    authorizationController.delegate = self
    authorizationController.presentationContextProvider = self
    authorizationController.performRequests()
  }

  @IBAction func didPressClose(_ sender: UIBarButtonItem) {
    self.viewModel.dismiss()
  }
}

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

extension LoginViewController: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    self.view.backgroundColor = theme.systemBackgroundColor

    self.overrideUserInterfaceStyle = theme.useDarkVariant
    ? UIUserInterfaceStyle.dark
    : UIUserInterfaceStyle.light

    self.setupProviderLoginView(theme.useDarkVariant)
  }
}
