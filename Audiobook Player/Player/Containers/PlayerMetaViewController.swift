//
//  PlayerMetaViewController.swift
//  Audiobook Player
//
//  Created by Florian Pichler on 05.04.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

class PlayerMetaViewController: PlayerContainerViewController {
    @IBOutlet private weak var authorLabel: UILabel!
    @IBOutlet private weak var bookLabel: UILabel!
    @IBOutlet weak var chapterLabel: UILabel!

    var author: String = "" {
        didSet {
            authorLabel.text = author
        }
    }

    var book: String = "" {
        didSet {
            bookLabel.text = book
        }
    }

    var chapter: String = "" {
        didSet {
            chapterLabel.text = chapter
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // @TODO: Create label view that fades out and scrolls
    // See https://stablekernel.com/how-to-fade-out-content-using-gradients-in-ios/
}
