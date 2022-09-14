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

class PlayPauseIconView: NibLoadableView {
  @IBOutlet weak var imageView: UIImageView!
  @IBOutlet weak var playButton: UIButton!

  let playImage = UIImage(systemName: "play.fill")!
  let pauseImage = UIImage(systemName: "pause.fill")!

  var isPlaying: Bool = false {
    didSet {
      self.imageView.image = self.isPlaying ? self.pauseImage : self.playImage

      self.playButton.accessibilityLabel = self.isPlaying ? Loc.PauseTitle.string : Loc.PlayTitle.string
    }
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)

    self.imageView.isAccessibilityElement = false
    self.playButton.accessibilityLabel = self.isPlaying ? Loc.PauseTitle.string : Loc.PlayTitle.string

    setUpTheming()
  }

  public func observeActionEvents() -> AnyPublisher<UIControl, Never> {
    return self.playButton.publisher(for: .touchUpInside).eraseToAnyPublisher()
  }
}

extension PlayPauseIconView: Themeable {
  func applyTheme(_ theme: ThemeManager.Theme) {
    self.tintColor = theme.linkColor
  }
}
