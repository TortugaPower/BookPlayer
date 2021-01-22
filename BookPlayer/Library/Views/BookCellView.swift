//
//  BookCellView.swift
//  BookPlayer
//
//  Created by Florian Pichler on 12.04.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import BookPlayerKit
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
    @IBOutlet weak var containerProgressView: UIView!
    @IBOutlet private weak var progressView: ItemProgress!
    @IBOutlet weak var durationLabel: UILabel!
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
            let roundedValue = self.progressView.roundedValue
            self.containerProgressView.isHidden = roundedValue == 0
            self.durationLabel.isHidden = roundedValue != 0
            
            setAccessibilityLabels()
        }
    }
    
    var duration: String? {
        get {
            return self.durationLabel.text
        }
        set {
            guard let value = newValue else { return }
            self.durationLabel.text = value
            self.durationLabel.isHidden = value.isEmpty
        }
    }

    var type: BookCellType = .book {
        didSet {
            switch self.type {
            case .playlist:
                self.accessoryType = .disclosureIndicator
            default:
                self.accessoryType = .none
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
        let resumeAction = UIAccessibilityCustomAction(name: "voiceover_continue_playback_title".localized, target: self, selector: #selector(self.artworkButtonTapped(_:)))
        accessibilityCustomActions = [resumeAction]
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
        accessibilityLabel = voiceOverService.bookCellView(type: self.type,
                                                           title: self.title,
                                                           subtitle: self.subtitle,
                                                           progress: self.progress)
    }
}

extension BookCellView: Themeable {
    func applyTheme(_ theme: Theme) {
        self.titleLabel.textColor = theme.primaryColor
        self.subtitleLabel.textColor = theme.detailColor
        self.durationLabel.textColor = theme.detailColor
        self.backgroundColor = theme.backgroundColor
        self.setPlaybackColors(theme)
        self.selectionView.defaultColor = theme.pieBorderColor
        self.selectionView.selectedColor = theme.highlightedPieFillColor
    }
}
