//
//  UIImageView+BookPlayer.swift
//  BookPlayer
//
//  Created by Florian Pichler on 09.05.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import Foundation
import UIKit

extension UIImageView {
    class func squircleMask(frame: CGRect) -> UIImageView {
        let backgroundMaskImage = UIImage(named: "nowPlayingMask")?.resizableImage(
            withCapInsets: UIEdgeInsets(top: 13.0, left: 13.0, bottom: 13.0, right: 13.0),
            resizingMode: .stretch
        )
        let backgroundMask = UIImageView(image: backgroundMaskImage)

        backgroundMask.frame = frame

        return backgroundMask
    }
}
