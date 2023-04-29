//
//  UIViewController+BookPlayer.swift
//  BookPlayer
//
//  Created by Florian Pichler on 28.04.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

extension UIViewController {
  func showAlert(_ content: BPAlertContent) {
    let alert = UIAlertController(
      title: content.title,
      message: content.message,
      preferredStyle: content.style
    )

    if let textInputPlaceholder = content.textInputPlaceholder {
      alert.addTextField(configurationHandler: { textfield in
        textfield.text = textInputPlaceholder
      })
    }

    content.actionItems.forEach({ item in
      let action = UIAlertAction(
        title: item.title,
        style: item.style,
        handler: { _ in
          if let text = alert.textFields?.first?.text,
             let inputHandler = item.inputHandler {
            inputHandler(text)
          } else {
            item.handler()
          }
        }
      )
      action.isEnabled = item.isEnabled
      alert.addAction(action)
    })

    self.present(alert, animated: true, completion: nil)
  }

    func showAlert(_ title: String?, message: String?, style: UIAlertController.Style = .alert, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: style)
        let okButton = UIAlertAction(title: "ok_button".localized, style: .default) { _ in
            completion?()
        }

        alert.addAction(okButton)

        self.present(alert, animated: true, completion: nil)
    }

    func formatSpeed(_ speed: Float) -> String {
        return (speed.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(speed))" : "\(speed)") + "×"
    }

    func animateView(_ view: UIView, show: Bool) {
        if show {
            self.showView(view)
        } else {
            self.hideView(view)
        }
    }

    func showView(_ view: UIView) {
        view.transform = CGAffineTransform(translationX: 0, y: view.bounds.height)
        view.alpha = 0.0
        view.isHidden = false

        UIView.animate(withDuration: 0.5,
                       delay: 0.0,
                       usingSpringWithDamping: 0.7,
                       initialSpringVelocity: 1.5,
                       options: .preferredFramesPerSecond60,
                       animations: {
                           view.transform = .identity
        })

        UIView.animate(withDuration: 0.3, delay: 0.0, options: .preferredFramesPerSecond60, animations: {
            view.alpha = 1.0
        })
    }

    func hideView(_ view: UIView) {
        UIView.animate(withDuration: 0.25,
                       delay: 0.0,
                       usingSpringWithDamping: 0.7,
                       initialSpringVelocity: 1.5,
                       options: .preferredFramesPerSecond60,
                       animations: {
                           view.transform = CGAffineTransform(translationX: 0, y: view.bounds.height)
                       },
                       completion: { _ in
                           view.isHidden = true
        })

        UIView.animate(withDuration: 0.15, delay: 0.0, options: [.preferredFramesPerSecond60, .curveEaseIn], animations: {
            view.alpha = 0.0
        })
    }

  func getTopViewController() -> UIViewController? {
    var top: UIViewController = self

    while true {
      if let presented = top.presentedViewController {
        top = presented
      } else {
        break
      }
    }

    return top
  }
}

extension UIViewController: AlertPresenter {
  func showAlert(_ title: String?, message: String?, completion: (() -> Void)?) {
    showAlert(title, message: message, style: .alert, completion: completion)
  }

  func showLoader() {
    if let navigationController {
      LoadingUtils.loadAndBlock(in: navigationController)
    } else {
      LoadingUtils.loadAndBlock(in: self)
    }
  }

  func stopLoader() {
    if let navigationController {
      LoadingUtils.stopLoading(in: navigationController)
    } else {
      LoadingUtils.stopLoading(in: self)
    }
  }
}
