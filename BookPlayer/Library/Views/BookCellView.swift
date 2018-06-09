//
//  BookCellView.swift
//  BookPlayer
//
//  Created by Florian Pichler on 12.04.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

class BookCellView: UITableViewCell {
    @IBOutlet private weak var artworkImageView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var progressTrailing: NSLayoutConstraint!
    @IBOutlet weak var progressView: ItemProgress!
    @IBOutlet weak var artworkButton: UIButton!

    var onArtworkTap: (() -> Void)?

    var artwork: UIImage? {
        get {
            return self.artworkImageView.image
        }
        set {
            self.artworkImageView.layer.cornerRadius = 4.0
            self.artworkImageView.layer.masksToBounds = true

            self.artworkImageView.image = newValue
        }
    }

    var title: String? {
        get {
            return self.titleLabel.text
        }
        set {
            self.titleLabel.text = newValue
        }
    }
    
    var titleColor: UIColor! {
        get {
            return self.titleLabel.textColor
        }
        set {
            self.titleLabel.textColor = newValue
        }
    }

    var subtitle: String? {
        get {
            return self.subtitleLabel.text
        }
        set {
            self.subtitleLabel.text = newValue
        }
    }

    var progress: Double {
        get {
            return self.progressView.value
        }
        set {
            self.progressView.value = newValue
        }
    }

    var isPlaylist: Bool = false {
        didSet {
            if self.isPlaylist {
                self.accessoryType = .disclosureIndicator

                self.progressTrailing.constant = 0

                // @TODO: Remove and calculate accumulated playlist progress
                self.progressView.isHidden = true
            } else {
                self.accessoryType = .none

                self.progressTrailing.constant = 16.0

                // @TODO: Remove and calculate accumulated playlist progress
                self.progressView.isHidden = false
            }
        }
    }

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        self.setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        self.setup()
    }

    private func setup() {
        self.accessoryType = .none
        self.selectionStyle = .none
    }

    @IBAction func artworkButtonTapped(_ sender: Any) {
        self.onArtworkTap?()
    }
}
