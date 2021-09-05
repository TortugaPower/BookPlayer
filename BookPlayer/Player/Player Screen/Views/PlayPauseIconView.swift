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

class PlayPauseIconView: NibLoadable {
  @IBOutlet weak var imageView: UIImageView!
  @IBOutlet weak var playButton: UIButton!

  let playImage = UIImage(systemName: "play.fill")!
  let pauseImage = UIImage(systemName: "pause.fill")!

  var isPlaying: Bool = false {
    didSet {
      self.imageView.image = self.isPlaying ? self.pauseImage : self.playImage

      self.playButton.accessibilityLabel = self.isPlaying ? "pause_title".localized : "play_title".localized
    }
  }

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    
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
