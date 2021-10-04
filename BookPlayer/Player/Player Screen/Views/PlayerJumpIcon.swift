//
//  PlayerJumpIconView.swift
//  BookPlayer
//
//  Created by Florian Pichler on 22.04.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import Themeable
import UIKit

class PlayerJumpIcon: UIView {
  fileprivate var backgroundImageView: UIImageView!
  fileprivate var label: UILabel!
  fileprivate var actionButton: UIButton!

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
    self.backgroundImageView.contentMode = .scaleAspectFill

    self.label = UILabel()
    self.label.allowsDefaultTighteningForTruncation = true
    self.label.adjustsFontSizeToFitWidth = true
    self.label.minimumScaleFactor = 0.95
    self.label.font = UIFont.systemFont(ofSize: 14.0, weight: .bold)
    self.label.textAlignment = .center
    self.label.textColor = self.tintColor

    self.actionButton = UIButton()

    self.addSubview(self.backgroundImageView)
    self.addSubview(self.label)
    self.addSubview(self.actionButton)

    self.label.isAccessibilityElement = false
    self.backgroundImageView.isAccessibilityElement = false

    setUpTheming()
  }

  override func layoutSubviews() {
    self.label.frame = self.bounds.insetBy(dx: 6.0, dy: 0.0)
    self.label.frame = CGRect(
      x: self.label.frame.origin.x,
      y: self.label.frame.origin.y + 1,
      width: self.label.frame.size.width,
      height: self.label.frame.size.height
    )
    self.backgroundImageView.frame = self.bounds.insetBy(dx: 0.0, dy: 0.0)
    self.actionButton.frame = self.bounds
  }

  public func observeActionEvents() -> AnyPublisher<UIControl, Never> {
    return self.actionButton.publisher(for: .touchUpInside).eraseToAnyPublisher()
  }
}

extension PlayerJumpIcon: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    self.label.textColor = theme.primaryColor
    self.backgroundImageView.tintColor = theme.primaryColor
    self.tintColor = theme.primaryColor
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

    self.title = "+\(Int(PlayerManager.forwardInterval.rounded())) "
    self.actionButton.accessibilityLabel = VoiceOverService.fastForwardText()
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

    self.title = "−\(Int(PlayerManager.rewindInterval.rounded())) "
    self.actionButton.accessibilityLabel = VoiceOverService.rewindText()
  }
}
