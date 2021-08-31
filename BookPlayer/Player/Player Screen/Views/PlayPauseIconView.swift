//
//  PlayPauseIconView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 12/8/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import Combine
import Themeable
import UIKit

class PlayPauseIconView: UIView {
  @IBOutlet weak var imageView: UIImageView!
  @IBOutlet weak var playButton: UIButton!

  let nibName = "PlayPauseIconView"
  var contentView: UIView?

  let playImage = UIImage(systemName: "play.fill")!
  let pauseImage = UIImage(systemName: "pause.fill")!

  var isPlaying: Bool = false {
    didSet {
      self.imageView.image = self.isPlaying ? self.pauseImage : self.playImage

      self.playButton.accessibilityLabel = self.isPlaying ? "pause_title".localized : "play_title".localized
    }
  }

  func loadViewFromNib() -> UIView? {
    let bundle = Bundle(for: type(of: self))
    let nib = UINib(nibName: nibName, bundle: bundle)
    return nib.instantiate(withOwner: self, options: nil).first as? UIView
  }

  required init?(coder aDecoder: NSCoder) {
      super.init(coder: aDecoder)

      guard let view = loadViewFromNib() else { return }
      view.frame = self.bounds
      self.addSubview(view)
      self.contentView = view

    self.imageView.isAccessibilityElement = false
    self.playButton.accessibilityLabel = self.isPlaying ? "pause_title".localized : "play_title".localized

      setUpTheming()
  }

  public func observeActionEvents() -> AnyPublisher<UIControl, Never> {
    return self.playButton.publisher(for: .touchUpInside).eraseToAnyPublisher()
  }
}

extension PlayPauseIconView: Themeable {
  func applyTheme(_ theme: ThemeManager.Theme) {
    self.tintColor = theme.primaryColor
  }
}
