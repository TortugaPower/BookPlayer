//
//  BookCellView.swift
//  BookPlayer
//
//  Created by Florian Pichler on 12.04.18.
//  Copyright © 2018 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Themeable
import UIKit

class BookCellView: UITableViewCell {
  @IBOutlet public weak var artworkView: BPArtworkView!
  @IBOutlet private weak var titleLabel: UILabel!
  @IBOutlet private weak var subtitleLabel: UILabel!
  @IBOutlet weak var containerChevronView: UIView!
  @IBOutlet weak var chevronImageView: UIImageView!
  @IBOutlet private weak var progressView: ItemProgress!
  @IBOutlet weak var durationLabel: UILabel!
  @IBOutlet weak var selectionView: CheckboxSelectionView!
  @IBOutlet private weak var artworkButton: UIButton!
  @IBOutlet weak var artworkWidth: NSLayoutConstraint!
  @IBOutlet weak var artworkHeight: NSLayoutConstraint!
  @IBOutlet weak var customSeparatorView: UIView!

  @IBOutlet weak var statusContainerView: UIView!
  @IBOutlet weak var downloadBackgroundView: UIView!
  @IBOutlet weak var downloadProgressView: ItemProgress!
  @IBOutlet weak var cloudImageView: UIImageView!
  @IBOutlet weak var cloudBackgroundView: UIView!

  var theme: SimpleTheme!
  var onArtworkTap: (() -> Void)?

  var title: String? {
    get {
      return self.titleLabel.text
    }
    set {
      self.titleLabel.text = newValue
    }
  }

  var subtitle: String? {
    get {
      return self.subtitleLabel.text
    }
    set {
      self.subtitleLabel.text = newValue
    }
  }

  var progress: Double {
    get {
      return self.progressView.value
    }
    set {
      self.progressView.value = (newValue.isNaN || newValue.isInfinite)
      ? 0.0
      : newValue
    }
  }

  var duration: String? {
    get {
      return self.durationLabel.text
    }
    set {
      guard let value = newValue else { return }
      self.durationLabel.text = value
    }
  }

  var type: SimpleItemType = .book {
    didSet {
      switch self.type {
      case .folder:
        containerChevronView.isHidden = false
      default:
        containerChevronView.isHidden = true
      }
    }
  }

  var playbackState: PlaybackState = PlaybackState.stopped {
    didSet {
      UIView.animate(withDuration: 0.1, animations: {
        self.setPlaybackColors(self.theme)
      })
    }
  }

  var downloadState: DownloadState = DownloadState.downloaded {
    didSet {
      switch self.downloadState {
      case .notDownloaded:
        statusContainerView.isHidden = false

        cloudBackgroundView.isHidden = false
        cloudImageView.isHidden = false

        downloadBackgroundView.isHidden = true
        downloadProgressView.isHidden = true
      case .downloading(let progress):
        statusContainerView.isHidden = false

        downloadBackgroundView.isHidden = false
        downloadProgressView.isHidden = false

        cloudBackgroundView.isHidden = true
        cloudImageView.isHidden = true

        downloadProgressView.value = progress
      case .downloaded:
        statusContainerView.isHidden = true
      }
    }
  }

  override func awakeFromNib() {
    super.awakeFromNib()
    self.setup()
    setUpTheming()
  }

  private func setup() {
    self.accessoryType = .none
    self.selectionStyle = .none
    let resumeAction = UIAccessibilityCustomAction(name: "voiceover_continue_playback_title".localized, target: self, selector: #selector(self.artworkButtonTapped(_:)))
    accessibilityCustomActions = [resumeAction]

    if let titleDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .subheadline).withSymbolicTraits(.traitBold) {
      self.titleLabel.font = UIFont(descriptor: titleDescriptor, size: 0.0)
      self.titleLabel.adjustsFontForContentSizeCategory = true
    }

    let subtitleDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .caption1)
    self.subtitleLabel.font = UIFont(descriptor: subtitleDescriptor, size: 0.0)
    self.subtitleLabel.adjustsFontForContentSizeCategory = true
    self.durationLabel.font = UIFont(descriptor: subtitleDescriptor, size: 0.0)
    self.durationLabel.adjustsFontForContentSizeCategory = true

    self.setupDownloadStatusViews()
  }

  func setupDownloadStatusViews() {
    self.downloadBackgroundView.alpha = 0.3
    /// Setup mask for cloud icon background
    let startingPoint = CGPoint(x: cloudBackgroundView.bounds.maxX, y: cloudBackgroundView.bounds.maxY)
    let path = UIBezierPath()
    path.move(to: startingPoint)
    path.addLine(to: CGPoint(x: cloudBackgroundView.bounds.maxX / 3, y: cloudBackgroundView.bounds.maxY))
    path.addLine(to: CGPoint(x: cloudBackgroundView.bounds.maxX, y: cloudBackgroundView.bounds.maxY / 3))
    path.addLine(to: startingPoint)

    let maskShape = CAShapeLayer()
    maskShape.path = path.cgPath
    cloudBackgroundView.layer.mask = maskShape
  }

  override func addSubview(_ view: UIView) {
    super.addSubview(view)

    if let controlClass = NSClassFromString("UITableViewCellEditControl"),
       view.isKind(of: controlClass) {
      view.isHidden = true
    }
  }

  override func willMove(toSuperview newSuperview: UIView?) {
    super.willMove(toSuperview: newSuperview)

    self.artworkButton.layer.cornerRadius = 4.0
    self.artworkButton.layer.masksToBounds = true
    self.cloudBackgroundView.layer.cornerRadius = 4.0
    self.cloudBackgroundView.layer.masksToBounds = true
  }

  @IBAction func artworkButtonTapped(_ sender: Any) {
    self.onArtworkTap?()
  }

  override func setSelected(_ selected: Bool, animated: Bool) {
    super.setSelected(selected, animated: animated)
    self.selectionView.isSelected = selected
  }

  override func setEditing(_ editing: Bool, animated: Bool) {
    super.setEditing(editing, animated: animated)

    progressView.isHidden = editing
    if type == .folder {
      containerChevronView.isHidden = editing
    }
  }

  func setPlaybackColors(_ theme: SimpleTheme) {
    switch self.playbackState {
    case .playing, .paused:
      self.artworkButton.backgroundColor = theme.linkColor.withAlpha(newAlpha: 0.3)
      self.titleLabel.textColor = theme.linkColor
      self.progressView.state = .highlighted
    case .stopped:
      self.artworkButton.backgroundColor = UIColor.clear
      self.titleLabel.textColor = theme.primaryColor
      self.progressView.state = .normal
    }
  }
}

// MARK: - Voiceover

extension BookCellView {
  public func setAccessibilityLabel(_ label: String) {
    isAccessibilityElement = true
    accessibilityLabel = label
  }
}

extension BookCellView: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    self.theme = theme
    self.titleLabel.textColor = theme.primaryColor
    self.subtitleLabel.textColor = theme.secondaryColor
    self.durationLabel.textColor = theme.secondaryColor
    self.backgroundColor = theme.systemBackgroundColor
    self.customSeparatorView.backgroundColor = theme.separatorColor
    self.setPlaybackColors(theme)
    self.selectionView.defaultColor = theme.secondarySystemFillColor
    self.selectionView.selectedColor = theme.systemFillColor
    self.chevronImageView.tintColor = theme.secondarySystemFillColor
    self.downloadBackgroundView.backgroundColor = theme.systemBackgroundColor
    self.cloudBackgroundView.backgroundColor = theme.systemGroupedBackgroundColor
    self.cloudImageView.tintColor = theme.linkColor
    self.overrideUserInterfaceStyle = theme.useDarkVariant
    ? UIUserInterfaceStyle.dark
    : UIUserInterfaceStyle.light
  }
}
