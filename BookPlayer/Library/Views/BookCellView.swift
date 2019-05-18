//
//  BookCellView.swift
//  BookPlayer
//
//  Created by Florian Pichler on 12.04.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import Themeable
import UIKit

enum PlaybackState {
    case playing
    case paused
    case stopped
}

enum BookCellType {
    case book
    case playlist
    case file // in a playlist
}

class BookCellView: UITableViewCell {
    @IBOutlet private weak var artworkView: BPArtworkView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var progressTrailing: NSLayoutConstraint!
    @IBOutlet private weak var progressView: ItemProgress!
    @IBOutlet weak var selectionView: CheckboxSelectionView!
    @IBOutlet private weak var artworkButton: UIButton!
    @IBOutlet weak var artworkWidth: NSLayoutConstraint!
    @IBOutlet weak var artworkHeight: NSLayoutConstraint!

    var onArtworkTap: (() -> Void)?

    var artwork: UIImage? {
        get {
            return self.artworkView.image
        }
        set {
            self.artworkView.image = newValue

            let ratio = self.artworkView.imageRatio

            self.artworkHeight.constant = ratio > 1 ? 50.0 / ratio : 50.0
            self.artworkWidth.constant = ratio < 1 ? 50.0 * ratio : 50.0
        }
    }

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
            self.progressView.value = newValue.isNaN
                ? 0.0
                : newValue
            setAccessibilityLabels()
        }
    }

    var type: BookCellType = .book {
        didSet {
            switch self.type {
            case .file:
                self.accessoryType = .none

                self.progressTrailing.constant = 11.0
            case .playlist:
                self.accessoryType = .disclosureIndicator

                self.progressTrailing.constant = -5.0
            default:
                self.accessoryType = .none

                self.progressTrailing.constant = 29.0 // Disclosure indicator offset
            }
        }
    }

    var playbackState: PlaybackState = PlaybackState.stopped {
        didSet {
            let currentTheme = self.themeProvider.currentTheme

            UIView.animate(withDuration: 0.1, animations: {
                self.setPlaybackColors(currentTheme)
            })
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
    }

    @IBAction func artworkButtonTapped(_ sender: Any) {
        self.onArtworkTap?()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        self.selectionView.isSelected = selected
    }

    func setPlaybackColors(_ theme: Theme) {
        switch self.playbackState {
        case .playing, .paused:
            self.artworkButton.backgroundColor = theme.lightHighlightColor
            self.titleLabel.textColor = theme.highlightColor
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
    private func setAccessibilityLabels() {
        let voiceOverService = VoiceOverService()
        isAccessibilityElement = true
        accessibilityLabel = voiceOverService.bookCellView(type: type,
                                                           title: title,
                                                           subtitle: subtitle,
                                                           progress: progress)
    }
}

extension BookCellView: Themeable {
    func applyTheme(_ theme: Theme) {
        self.titleLabel.textColor = theme.primaryColor
        self.subtitleLabel.textColor = theme.detailColor
        self.backgroundColor = theme.backgroundColor
        self.setPlaybackColors(theme)
        self.selectionView.defaultColor = theme.pieBorderColor
        self.selectionView.selectedColor = theme.highlightedPieFillColor
    }
}
