//
//  BPArtworkView.swift
//  BookPlayer
//
//  Created by Florian Pichler on 24.06.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

class BPArtworkView: UIImageView {
    var imageRatio: CGFloat {
        guard let image = self.image else {
            return 1.0
        }

        return image.size.width / image.size.height
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        setup()
    }

    private func setup() {
        layer.cornerRadius = 4.0
        layer.masksToBounds = true
        clipsToBounds = true

        layer.borderWidth = 0.5
        layer.borderColor = UIColor.textColor.withAlphaComponent(0.2).cgColor
    }
}
