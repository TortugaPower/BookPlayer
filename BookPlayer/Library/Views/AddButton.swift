//
//  AddButton.swift
//  BookPlayer
//
//  Created by Florian Pichler on 03.06.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import Themeable
import UIKit

class AddButton: UIButton {
    override func awakeFromNib() {
        super.awakeFromNib()

        self.setup()
        setUpTheming()
    }

    private func setup() {
        let add = UIImageView(image: #imageLiteral(resourceName: "listAdd"))
        let distance: CGFloat = 15.0

        add.tintColor = UIColor.tintColor

        self.setImage(add.image, for: .normal)

        self.imageEdgeInsets.right = distance
        self.titleEdgeInsets.left = distance
    }
}

extension AddButton: Themeable {
    func applyTheme(_ theme: Theme) {
        self.setTitleColor(theme.highlightColor, for: .normal)
    }
}
