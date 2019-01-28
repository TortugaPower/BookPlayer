//
//  ThemeCellView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 1/18/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import Themeable
import UIKit

class ThemeCellView: UITableViewCell {
    @IBOutlet weak var showCaseLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var plusImageView: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()

        self.showCaseLabel.layer.borderWidth = 2.0
        self.showCaseLabel.layer.cornerRadius = 5.0
        setUpTheming()
    }
}

extension ThemeCellView: Themeable {
    func applyTheme(_ theme: Theme) {
        self.titleLabel?.textColor = theme.primary
        self.backgroundColor = theme.background
    }
}
