//
//  PlayerJumpIconView.swift
//  BookPlayer
//
//  Created by Florian Pichler on 22.04.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

class PlayerJumpIcon: UIView {
    private var backgroundImageView: UIImageView!
    private var label: UILabel!

    var backgroundImage: UIImage = UIImage()

    var title: String = "" {
        didSet {
            self.label.text = self.title
        }
    }

    override var tintColor: UIColor! {
        didSet {
            self.backgroundImageView.tintColor = self.tintColor
            self.label.textColor = self.tintColor
        }
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        setup()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
    }

    fileprivate func setup() {
        backgroundColor = .clear

        backgroundImageView = UIImageView(image: backgroundImage)
        backgroundImageView.tintColor = tintColor

        label = UILabel()
        label.allowsDefaultTighteningForTruncation = true
        label.adjustsFontSizeToFitWidth = true
        label.font = UIFont.systemFont(ofSize: 14.0, weight: .bold)
        label.textAlignment = .center
        label.textColor = tintColor

        addSubview(backgroundImageView)
        addSubview(label)
    }

    override func layoutSubviews() {
        label.frame = bounds.insetBy(dx: 10.0, dy: 10.0)
    }
}

class PlayerJumpIconForward: PlayerJumpIcon {
    override var backgroundImage: UIImage {
        get {
            return #imageLiteral(resourceName: "playerIconForward")
        }
        set {
            super.backgroundImage = newValue
        }
    }

    override func setup() {
        super.setup()

        title = "+\(Int(PlayerManager.shared.forwardInterval.rounded()))s"
    }
}

class PlayerJumpIconRewind: PlayerJumpIcon {
    override var backgroundImage: UIImage {
        get {
            return #imageLiteral(resourceName: "playerIconRewind")
        }
        set {
            super.backgroundImage = newValue
        }
    }

    override func setup() {
        super.setup()

        title = "−\(Int(PlayerManager.shared.rewindInterval.rounded()))s"
    }
}
