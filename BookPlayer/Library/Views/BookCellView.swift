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
    @IBOutlet weak var completionLabel: UILabel!
    @IBOutlet private weak var completionLabelTrailing: NSLayoutConstraint!

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

    var subtitle: String? {
        get {
            return self.subtitleLabel.text
        }
        set {
            self.subtitleLabel.text = newValue
        }
    }

    var isPlaylist: Bool = false {
        didSet {
            if self.isPlaylist {
                self.accessoryType = .disclosureIndicator

                self.completionLabelTrailing.constant = 0

                self.completionLabel.isHidden = true
            } else {
                self.accessoryType = .none

                self.completionLabelTrailing.constant = 16.0

                self.completionLabel.isHidden = false
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
}
