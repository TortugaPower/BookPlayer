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

class LoginViewController: BaseViewController<AccountCoordinator, AccountViewModel>,
                           Storyboarded {
  @IBOutlet weak var loginProviderStackView: UIStackView!

  override func viewDidLoad() {
    super.viewDidLoad()
    self.navigationController?.setNavigationBarHidden(true, animated: false)

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
}

extension LoginViewController: ASAuthorizationControllerDelegate {
  /// - Tag: did_complete_authorization
  func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
    switch authorization.credential {
    case let appleIDCredential as ASAuthorizationAppleIDCredential:

      // Create an account in your system.
      let userIdentifier = appleIDCredential.user
      let fullName = appleIDCredential.fullName
      let email = appleIDCredential.email

      // For the purpose of this demo app, store the `userIdentifier` in the keychain.
      self.saveUserInKeychain(userIdentifier)

      // For the purpose of this demo app, show the Apple ID credential information in the `ResultViewController`.
      self.showResultViewController(userIdentifier: userIdentifier, fullName: fullName, email: email)

    case let passwordCredential as ASPasswordCredential:

      // Sign in using an existing iCloud Keychain credential.
      let username = passwordCredential.user
      let password = passwordCredential.password

      // For the purpose of this demo app, show the password credential as an alert.
      DispatchQueue.main.async {
        self.showPasswordCredentialAlert(username: username, password: password)
      }

    default:
      break
    }
  }

  private func saveUserInKeychain(_ userIdentifier: String) {
    //        do {
    //            try KeychainItem(service: "com.example.apple-samplecode.juice", account: "userIdentifier").saveItem(userIdentifier)
    //        } catch {
    //            print("Unable to save userIdentifier to keychain.")
    //        }
  }

  private func showResultViewController(userIdentifier: String, fullName: PersonNameComponents?, email: String?) {
    //        guard let viewController = self.presentingViewController as? ResultViewController
    //            else { return }
    //
    //        DispatchQueue.main.async {
    //            viewController.userIdentifierLabel.text = userIdentifier
    //            if let givenName = fullName?.givenName {
    //                viewController.givenNameLabel.text = givenName
    //            }
    //            if let familyName = fullName?.familyName {
    //                viewController.familyNameLabel.text = familyName
    //            }
    //            if let email = email {
    //                viewController.emailLabel.text = email
    //            }
    //            self.dismiss(animated: true, completion: nil)
    //        }
  }

  private func showPasswordCredentialAlert(username: String, password: String) {
    let message = "The app has received your selected credential from the keychain. \n\n Username: \(username)\n Password: \(password)"
    let alertController = UIAlertController(title: "Keychain Credential Received",
                                            message: message,
                                            preferredStyle: .alert)
    alertController.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
    self.present(alertController, animated: true, completion: nil)
  }

  /// - Tag: did_complete_error
  func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
    // Handle error.
    print(error.localizedDescription)
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
