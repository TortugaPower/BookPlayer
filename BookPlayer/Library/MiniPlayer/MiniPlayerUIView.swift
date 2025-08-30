//
//  MiniPlayerUIView.swift
//  BookPlayer
//
//  Created by gianni.carlo on 12/3/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import MarqueeLabel
import Themeable
import UIKit

class MiniPlayerUIView: UIView {
  @IBOutlet private weak var containerView: UIView!
  @IBOutlet private weak var artwork: BPArtworkView!
  @IBOutlet private weak var titleLabel: BPMarqueeLabel!
  @IBOutlet private weak var authorLabel: BPMarqueeLabel!
  @IBOutlet weak var playIconView: PlayPauseIconView!

  private var disposeBag = Set<AnyCancellable>()

  var onPlayerTap: (() -> Void)?
  var onPlayPauseTap: (() -> Void)?

  override func awakeFromNib() {
    self.backgroundColor = .clear

    setUpTheming()

    self.containerView.layer.cornerRadius = 13.0
    self.containerView.layer.masksToBounds = true
    self.playIconView.imageView.contentMode = .scaleAspectFit

    let tap = UITapGestureRecognizer(target: self, action: #selector(self.tapAction))
    tap.cancelsTouchesInView = true

    self.addGestureRecognizer(tap)

    self.playIconView.observeActionEvents()
      .sink { [weak self] _ in
        self?.onPlayPauseTap?()
      }
      .store(in: &disposeBag)
  }

  func setupPlayerView(
    with title: String,
    author: String,
    relativePath: String
  ) {
    self.setNeedsLayout()

    self.artwork.kf.setImage(
      with: ArtworkService.getArtworkProvider(for: relativePath),
      placeholder: ArtworkService.generateDefaultArtwork(
        from: themeProvider.currentTheme.linkColor
      ),
      options: [.targetCache(ArtworkService.cache)]
    )
    self.authorLabel.text = author
    self.titleLabel.text = title

    setVoiceOverLabels()
    applyTheme(self.themeProvider.currentTheme)
  }

  // MARK: Gesture recognizers

  @objc func tapAction() {
    self.onPlayerTap?()
  }

  // MARK: - Voiceover

  private func setVoiceOverLabels() {
    let voiceOverTitle = self.titleLabel.text ?? "voiceover_no_title".localized
    let voiceOverSubtitle = self.authorLabel.text ?? "voiceover_no_author".localized
    self.titleLabel.accessibilityLabel = "voiceover_miniplayer_hint".localized
    + ", "
    + String(describing: String.localizedStringWithFormat("voiceover_currently_playing_title".localized, voiceOverTitle, voiceOverSubtitle))
    self.titleLabel.accessibilityTraits =  [.header]
    self.playIconView.accessibilityLabel = "play_title".localized
    self.artwork.isAccessibilityElement = false
  }
}

extension MiniPlayerUIView: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    self.titleLabel.textColor = theme.primaryColor
    self.authorLabel.textColor = theme.secondaryColor
    self.playIconView.tintColor = theme.linkColor

    self.containerView.backgroundColor = theme.secondarySystemBackgroundColor
  }
}
