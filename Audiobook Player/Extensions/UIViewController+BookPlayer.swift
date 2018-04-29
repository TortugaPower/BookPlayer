//
//  UIViewController+BookPlayer.swift
//  Audiobook Player
//
//  Created by Florian Pichler on 28.04.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

extension UIViewController {
    func showAlert(_ title: String?, message: String?, style: UIAlertControllerStyle) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: style)
        let okButton = UIAlertAction(title: "Ok", style: .default, handler: nil)

        alert.addAction(okButton)

        alert.popoverPresentationController?.sourceView = self.view
        alert.popoverPresentationController?.sourceRect = CGRect(x: Double(self.view.bounds.size.width / 2.0), y: Double(self.view.bounds.size.height-45), width: 1.0, height: 1.0)

        self.present(alert, animated: true, completion: nil)
    }

    // utility function to transform seconds to format MM:SS or HH:MM:SS
    func formatTime(_ time: TimeInterval) -> String {
        let durationFormatter = DateComponentsFormatter()

        durationFormatter.unitsStyle = .positional
        durationFormatter.allowedUnits = [ .minute, .second ]
        durationFormatter.zeroFormattingBehavior = .pad
        durationFormatter.collapsesLargestUnit = false

        if time > 3599.0 {
            durationFormatter.allowedUnits = [ .hour, .minute, .second ]
        }

        return durationFormatter.string(from: time)!
    }
}
