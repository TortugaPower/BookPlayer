//
//  UIViewController+BookPlayer.swift
//  BookPlayer
//
//  Created by Florian Pichler on 28.04.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

extension UIViewController {
    func showAlert(_ title: String?, message: String?, style: UIAlertController.Style = .alert, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: style)
        let okButton = UIAlertAction(title: Loc.OkButton.string, style: .default) { _ in
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
