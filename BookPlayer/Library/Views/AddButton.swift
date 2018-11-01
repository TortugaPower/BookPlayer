//
//  AddButton.swift
//  BookPlayer
//
//  Created by Florian Pichler on 03.06.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

class AddButton: UIButton {
    override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        setup()
    }

    private func setup() {
        let add = UIImageView(image: #imageLiteral(resourceName: "listAdd"))
        let distance: CGFloat = 15.0

        add.tintColor = UIColor.tintColor

        setImage(add.image, for: .normal)

        imageEdgeInsets.right = distance
        titleEdgeInsets.left = distance
    }
}
