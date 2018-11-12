//
//  BPMarqueeLabel.swift
//  BookPlayer
//
//  Created by Florian Pichler on 10.05.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import MarqueeLabelSwift
import UIKit

class BPMarqueeLabel: MarqueeLabel {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        self.animationDelay = 2.0
        self.speed = .rate(7.5)
        self.fadeLength = 10.0
        self.leadingBuffer = 10.0
        self.trailingBuffer = 10.0
    }
}
