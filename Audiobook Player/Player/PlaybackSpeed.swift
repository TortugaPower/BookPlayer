//
//  PlaybackSpeed.swift
//  Audiobook Player
//
//  Created by Florian Pichler on 01.04.18.
//  Copyright © 2018 Florian Pichler.
//

import UIKit

typealias PlaybackSpeedSelect = (Float) -> Void

class PlaybackSpeed {
    static let shared = PlaybackSpeed()

    let speedOptions: [Float] = [2.5, 2.0, 1.5, 1.25, 1.0, 0.75]

    private init() { }

    func actionSheet(onSelect: @escaping PlaybackSpeedSelect, currentSpeed: Float = 1.0) -> UIAlertController {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        alert.message = "Set playback speed"

        for speed in self.speedOptions {
            alert.addAction(UIAlertAction(title: speed == currentSpeed ? "\u{00A0} \(speed) ✓" : "\(speed)", style: .default, handler: speed == currentSpeed ? nil : { _ in
                onSelect(speed)
            }))
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        return alert
    }

    func format(_ speed: Float) -> String {
        return "\(String(speed))x"
    }
}
