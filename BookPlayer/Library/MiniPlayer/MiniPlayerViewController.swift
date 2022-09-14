//
//  NowPlayingViewController.swift
//  BookPlayer
//
//  Created by Florian Pichler on 08.05.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import MarqueeLabel
import Themeable
import UIKit

class MiniPlayerViewController: BaseViewController<MainCoordinator, MiniPlayerViewModel>,
                                UIGestureRecognizerDelegate,
                                Storyboarded {
  @IBOutlet private weak var miniPlayerBlur: UIVisualEffectView!
  @IBOutlet private weak var miniPlayerContainer: UIView!
  @IBOutlet private weak var artwork: BPArtworkView!
  @IBOutlet private weak var titleLabel: BPMarqueeLabel!
  @IBOutlet private weak var authorLabel: BPMarqueeLabel!
  @IBOutlet weak var playIconView: PlayPauseIconView!
  @IBOutlet private weak var artworkWidth: NSLayoutConstraint!
  @IBOutlet private weak var artworkHeight: NSLayoutConstraint!

  private var disposeBag = Set<AnyCancellable>()

  private var tap: UITapGestureRecognizer!

  override func viewDidLoad() {
    super.viewDidLoad()

    self.view.backgroundColor = .clear

    setUpTheming()

    self.miniPlayerBlur.layer.cornerRadius = 13.0
    self.miniPlayerBlur.layer.masksToBounds = true

    self.playIconView.imageView.contentMode = .scaleAspectFit

    self.tap = UITapGestureRecognizer(target: self, action: #selector(self.tapAction))
    self.tap.cancelsTouchesInView = true

    self.view.addGestureRecognizer(self.tap)

    bindObservers()
  }

  func setupPlayerView(with currentItem: PlayableItem) {
    self.view.setNeedsLayout()

    self.artwork.kf.setImage(
      with: ArtworkService.getArtworkProvider(for: currentItem.relativePath),
      placeholder: ArtworkService.generateDefaultArtwork(
        from: themeProvider.currentTheme.linkColor
      ),
      options: [.targetCache(ArtworkService.cache)]
    )
    self.authorLabel.text = currentItem.author
    self.titleLabel.text = currentItem.title

    setVoiceOverLabels()
    applyTheme(self.themeProvider.currentTheme)
  }

  func bindObservers() {
    self.viewModel.isPlayingObserver()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] isPlaying in
        self?.playIconView.isPlaying = isPlaying
      }
      .store(in: &disposeBag)

    self.viewModel.currentItemObserver().sink { [weak self] item in
      guard let item = item else {
        self?.view.isHidden = true
        return
      }

      self?.view.isHidden = false
      self?.setupPlayerView(with: item)
    }.store(in: &disposeBag)

    self.playIconView.observeActionEvents()
      .sink { [weak self] _ in
        self?.viewModel.handlePlayPauseAction()
      }
      .store(in: &disposeBag)
  }

  // MARK: Gesture recognizers

  @objc func tapAction() {
    self.viewModel.showPlayer()
  }

  // MARK: - Voiceover

  private func setVoiceOverLabels() {
    let voiceOverTitle = self.titleLabel.text ?? Loc.VoiceoverNoTitle.string
    let voiceOverSubtitle = self.authorLabel.text ?? Loc.VoiceoverNoAuthor.string
    self.titleLabel.accessibilityLabel = Loc.VoiceoverMiniplayerHint.string
    + ", "
    + String(describing: Loc.VoiceoverCurrentlyPlayingTitle(voiceOverTitle, voiceOverSubtitle).string)
    self.titleLabel.accessibilityTraits =  [.header]
    self.playIconView.accessibilityLabel = Loc.PlayingTitle.string
    self.artwork.isAccessibilityElement = false
  }
}

extension MiniPlayerViewController: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    self.titleLabel.textColor = theme.primaryColor
    self.authorLabel.textColor = theme.secondaryColor
    self.playIconView.tintColor = theme.linkColor

    self.miniPlayerContainer.backgroundColor = theme.secondarySystemBackgroundColor

    self.miniPlayerBlur.effect = theme.useDarkVariant
      ? UIBlurEffect(style: .dark)
      : UIBlurEffect(style: .light)
  }
}
