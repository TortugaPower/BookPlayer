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
    @IBOutlet weak var iconImageView: BPArtworkView!

    override func awakeFromNib() {
        super.awakeFromNib()

        self.iconImageView.layer.cornerRadius = 9
        setUpTheming()
    }
}

extension IconCellView: Themeable {
    func applyTheme(_ theme: Theme) {
        self.titleLabel?.textColor = theme.primaryColor
        self.backgroundColor = theme.backgroundColor
    }
}
