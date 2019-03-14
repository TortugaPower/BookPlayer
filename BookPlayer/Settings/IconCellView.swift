//
//  IconCellView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/19/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import Themeable
import UIKit

class IconCellView: UITableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var authorLabel: UILabel!
    @IBOutlet private weak var iconImageView: UIImageView!

    var iconImage: UIImage? {
        didSet {
            self.iconImageView.image = iconImage?.addLayerMask("appIconMask")
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        setUpTheming()
    }
}

extension IconCellView: Themeable {
    func applyTheme(_ theme: Theme) {
        self.titleLabel.textColor = theme.primaryColor
        self.authorLabel.textColor = theme.detailColor
        self.backgroundColor = theme.backgroundColor
    }
}
