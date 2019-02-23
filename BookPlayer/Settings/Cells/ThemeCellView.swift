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
    @IBOutlet weak var showCaseView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var plusImageView: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()

        self.showCaseView.layer.shadowColor = UIColor.black.cgColor
        self.showCaseView.layer.shadowOffset = CGSize(width: 0, height: 0)
        self.showCaseView.layer.shadowOpacity = 0.4
        self.showCaseView.layer.shadowRadius = 1.0

        setUpTheming()
    }

    func setupShowCaseView(for theme: Theme) {
        self.showCaseView.layer.sublayers = nil
        self.showCaseView.addLayerMask("themeColorBackgroundMask", backgroundColor: theme.defaultBackgroundColor)
        self.showCaseView.addLayerMask("themeColorAccentMask", backgroundColor: theme.defaultAccentColor)
        self.showCaseView.addLayerMask("themeColorPrimaryMask", backgroundColor: theme.defaultPrimaryColor)
        self.showCaseView.addLayerMask("themeColorSecondaryMask", backgroundColor: theme.defaultSecondaryColor)
    }
}

extension ThemeCellView: Themeable {
    func applyTheme(_ theme: Theme) {
        self.titleLabel?.textColor = theme.primaryColor
        self.backgroundColor = theme.backgroundColor
    }
}
