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
        let okButton = UIAlertAction(title: "OK", style: .default) { _ in
            completion?()
        }

        alert.addAction(okButton)

        self.present(alert, animated: true, completion: nil)
    }

    // utility function to transform seconds to format MM:SS or HH:MM:SS
    func formatTime(_ time: TimeInterval) -> String {
        let durationFormatter = DateComponentsFormatter()

        durationFormatter.unitsStyle = .positional
        durationFormatter.allowedUnits = [.minute, .second]
        durationFormatter.zeroFormattingBehavior = .pad
        durationFormatter.collapsesLargestUnit = false

        if abs(time) > 3599.0 {
            durationFormatter.allowedUnits = [.hour, .minute, .second]
        }

        return durationFormatter.string(from: time)!
    }

    func formatDuration(_ duration: TimeInterval, unitsStyle: DateComponentsFormatter.UnitsStyle = .short) -> String {
        let durationFormatter = DateComponentsFormatter()

        durationFormatter.unitsStyle = unitsStyle
        durationFormatter.allowedUnits = [.minute, .second]
        durationFormatter.collapsesLargestUnit = true

        return durationFormatter.string(from: duration)!
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
}
