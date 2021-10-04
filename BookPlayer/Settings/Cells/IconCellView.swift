//
//  IconCellView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/19/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Themeable
import UIKit

class IconCellView: UITableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var authorLabel: UILabel!
    @IBOutlet private weak var iconImageView: UIImageView!
    @IBOutlet weak var lockImageView: UIImageView!

    var iconImage: UIImage? {
        didSet {
            self.iconImageView.image = self.iconImage?.addLayerMask("appIconMask")
        }
    }

    var isLocked: Bool = false {
        didSet {
            self.titleLabel.alpha = self.isLocked ? 0.5 : 1.0
            self.iconImageView.alpha = self.isLocked ? 0.5 : 1.0
            self.lockImageView.isHidden = !self.isLocked
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        setUpTheming()
    }
}

extension IconCellView: Themeable {
    func applyTheme(_ theme: SimpleTheme) {
        self.titleLabel.textColor = theme.primaryColor
        self.authorLabel.textColor = theme.secondaryColor
        self.lockImageView.tintColor = theme.linkColor
        self.backgroundColor = theme.systemBackgroundColor
    }
}
