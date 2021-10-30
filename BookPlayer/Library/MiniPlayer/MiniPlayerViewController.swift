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

class MiniPlayerViewController: UIViewController, UIGestureRecognizerDelegate, Storyboarded {
  @IBOutlet private weak var miniPlayerBlur: UIVisualEffectView!
  @IBOutlet private weak var miniPlayerContainer: UIView!
  @IBOutlet private weak var artwork: BPArtworkView!
  @IBOutlet private weak var titleLabel: BPMarqueeLabel!
  @IBOutlet private weak var authorLabel: BPMarqueeLabel!
  @IBOutlet weak var playIconView: PlayPauseIconView!
  @IBOutlet private weak var artworkWidth: NSLayoutConstraint!
  @IBOutlet private weak var artworkHeight: NSLayoutConstraint!

  private var disposeBag = Set<AnyCancellable>()
  public var viewModel: MiniPlayerViewModel!

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

  func setupPlayerView(with currentBook: Book) {
    self.view.setNeedsLayout()

    self.artwork.kf.setImage(with: ArtworkService.getArtworkProvider(for: currentBook.relativePath),
                             placeholder: ArtworkService.generateDefaultArtwork(from: themeProvider.currentTheme.linkColor))
    self.authorLabel.text = currentBook.author
    self.titleLabel.text = currentBook.title

    setVoiceOverLabels()
    applyTheme(self.themeProvider.currentTheme)
  }

  func bindObservers() {
    self.viewModel.isPlayingObserver()
      .receive(on: DispatchQueue.main)
      .sink { isPlaying in
        self.playIconView.isPlaying = isPlaying
      }
      .store(in: &disposeBag)

    self.viewModel.currentBookObserver().sink { [weak self] book in
      guard let book = book else {
        self?.view.isHidden = true
        return
      }

      self?.view.isHidden = false
      self?.setupPlayerView(with: book)
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
    let voiceOverTitle = self.titleLabel.text ?? "voiceover_no_title".localized
    let voiceOverSubtitle = self.authorLabel.text ?? "voiceover_no_author".localized
    self.titleLabel.accessibilityLabel = String(describing: String.localizedStringWithFormat("voiceover_currently_playing_title".localized, voiceOverTitle, voiceOverSubtitle))
    self.titleLabel.accessibilityHint = "voiceover_miniplayer_hint".localized
    self.playIconView.accessibilityLabel = "play_title".localized
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
