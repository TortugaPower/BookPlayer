//
//  PlayerMetaViewController.swift
//  Audiobook Player
//
//  Created by Florian Pichler on 05.04.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit
import MarqueeLabelSwift

class PlayerMetaViewController: PlayerContainerViewController {
    @IBOutlet private weak var _authorLabel: MarqueeLabel!
    @IBOutlet private weak var _titleLabel: MarqueeLabel!
    @IBOutlet private weak var _chapterLabel: MarqueeLabel!

    var book: Book? {
        didSet {
            _authorLabel.text = book?.author
            _titleLabel.text = book?.title
        }
    }

    var chapterLabel: String = "" {
        didSet {
            self._chapterLabel.text = chapterLabel
            self._chapterLabel.isEnabled = chapterLabel != ""
        }
    }

    var chapters: [Chapter] = []

    var colors: [UIColor] = [.white, .white, .white] {
        didSet {
            self._authorLabel.textColor = colors[0]
            self._titleLabel.textColor = colors[1]
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let labels: [MarqueeLabel] = [self._authorLabel, self._titleLabel, self._chapterLabel]

        for label in labels {
            label.animationDelay = 2.0
            label.speed = .rate(7.5)
            label.fadeLength = 10.0
            label.leadingBuffer = 10.0
            label.trailingBuffer = 10.0
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // @TODO: Create label view that fades out and scrolls
    // See https://stablekernel.com/how-to-fade-out-content-using-gradients-in-ios/
}
