//
//  PlusBannerView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/27/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Themeable
import UIKit

class PlusBannerView: NibLoadableView {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
    @IBOutlet weak var moreButton: UIButton!

    var showPlus: (() -> Void)?

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        setUpTheming()
    }

    @IBAction func showPlus(_ sender: UIButton) {
      self.showPlus?()
    }
}

extension PlusBannerView: Themeable {
    func applyTheme(_ theme: ThemeManager.Theme) {
        self.titleLabel.textColor = theme.primaryColor
        self.detailLabel.textColor = theme.secondaryColor
        self.moreButton.backgroundColor = theme.linkColor
        self.backgroundColor = theme.systemGroupedBackgroundColor
    }
}
