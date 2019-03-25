//
//  PlayerJumpIconView.swift
//  BookPlayer
//
//  Created by Florian Pichler on 22.04.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

class PlayerJumpIcon: UIView {
    fileprivate var backgroundImageView: UIImageView!
    fileprivate var label: UILabel!

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

        self.setup()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.setup()
    }

    fileprivate func setup() {
        self.backgroundColor = .clear

        self.backgroundImageView = UIImageView(image: self.backgroundImage)
        self.backgroundImageView.tintColor = self.tintColor

        self.label = UILabel()
        self.label.allowsDefaultTighteningForTruncation = true
        self.label.adjustsFontSizeToFitWidth = true
        self.label.font = UIFont.systemFont(ofSize: 14.0, weight: .bold)
        self.label.textAlignment = .center
        self.label.textColor = self.tintColor

        self.label.layer.shadowOpacity = 0.8
        self.label.layer.shadowOffset = CGSize(width: 0, height: 0)

        self.addSubview(self.backgroundImageView)
        self.addSubview(self.label)
    }

    override func layoutSubviews() {
        self.label.frame = self.bounds.insetBy(dx: 10.0, dy: 10.0)
        self.backgroundImageView.center = self.label.center
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

        self.backgroundImageView.addLayerMask("playerIconShadow", backgroundColor: .playerControlsShadowColor)
        self.backgroundImageView.addLayerMask("playerIconForwardArrowShadow", backgroundColor: .black)
        self.backgroundImageView.addLayerMask("playerIconForward", backgroundColor: .white)
        self.title = "+\(Int(PlayerManager.shared.forwardInterval.rounded()))s"
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

        self.backgroundImageView.addLayerMask("playerIconShadow", backgroundColor: .playerControlsShadowColor)
        self.backgroundImageView.addLayerMask("playerIconRewindArrowShadow", backgroundColor: .black)
        self.backgroundImageView.addLayerMask("playerIconRewind", backgroundColor: .white)
        self.title = "−\(Int(PlayerManager.shared.rewindInterval.rounded()))s"
    }
}
