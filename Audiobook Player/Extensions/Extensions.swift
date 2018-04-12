//
// Extensions.swift
// Audiobook Player
//
// Created by Gianni Carlo on 3/10/17.
// Copyright © 2017 Tortuga Power. All rights reserved.
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

extension Notification.Name {
    public struct AudiobookPlayer {
        public static let openURL = Notification.Name(rawValue: "com.tortugapower.audiobookplayer.openurl")
        public static let requestReview = Notification.Name(rawValue: "com.tortugapower.audiobookplayer.requestreview")
        public static let updateTimer = Notification.Name(rawValue: "com.tortugapower.audiobookplayer.book.timer")
        public static let updatePercentage = Notification.Name(rawValue: "com.tortugapower.audiobookplayer.book.percentage")
        public static let updateChapter = Notification.Name(rawValue: "com.tortugapower.audiobookplayer.book.chapter")
        public static let errorLoadingBook = Notification.Name(rawValue: "com.tortugapower.audiobookplayer.book.error")
        public static let bookReady = Notification.Name(rawValue: "com.tortugapower.audiobookplayer.book.ready")
        public static let bookPlayed = Notification.Name(rawValue: "com.tortugapower.audiobookplayer.book.play")
        public static let bookPaused = Notification.Name(rawValue: "com.tortugapower.audiobookplayer.book.pause")
        public static let bookEnd = Notification.Name(rawValue: "com.tortugapower.audiobookplayer.book.end")
        public static let bookChange = Notification.Name(rawValue: "com.tortugapower.audiobookplayer.book.change")
        public static let bookPlaying = Notification.Name(rawValue: "com.tortugapower.audiobookplayer.book.playback")
    }
}

// swiftlint:disable identifier_name

func XYZtoLAB(_ value: CGFloat) -> (CGFloat) {
    var newValue: CGFloat = value

    if ((value > pow((6.0/29.0), 3.0)) ) {
        newValue = pow(newValue, 1.0/3.0)
    } else {
        newValue = (1/3) * pow((29.0/6.0), 2.0) * newValue + 4/29.0
    }

    return newValue
}

func RGBtoSRGB(_ value: CGFloat) -> (CGFloat) {
    var newValue = value

    if newValue > 0.04045 {
        newValue = pow(((newValue + 0.055) / (1 + 0.055)), 2.40)
    } else {
        newValue /= 12.92
    }

    return newValue
}

extension UIColor {
    var RGBA: [CGFloat] {
        var R: CGFloat = 0
        var G: CGFloat = 0
        var B: CGFloat = 0
        var A: CGFloat = 0

        self.getRed(&R, green: &G, blue: &B, alpha: &A)

        return [RGBtoSRGB(R), RGBtoSRGB(G), RGBtoSRGB(B), A]
    }

    var luminance: CGFloat {
        // http://www.w3.org/WAI/GL/WCAG20-TECHS/G18.html

        let RGBA = self.RGBA

        func lumHelper(c: CGFloat) -> CGFloat {
            return (c < 0.03928) ? (c/12.92): pow((c+0.055)/1.055, 2.4)
        }

        return 0.2126 * lumHelper(c: RGBA[0]) + 0.7152 * lumHelper(c: RGBA[1]) + 0.0722 * lumHelper(c: RGBA[2])
    }
}
