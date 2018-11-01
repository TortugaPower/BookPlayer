//
//  BookCellView.swift
//  BookPlayer
//
//  Created by Florian Pichler on 12.04.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

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
    @IBOutlet private var artworkView: BPArtworkView!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var subtitleLabel: UILabel!
    @IBOutlet private var progressTrailing: NSLayoutConstraint!
    @IBOutlet private var progressView: ItemProgress!
    @IBOutlet private var artworkButton: UIButton!
    @IBOutlet var artworkWidth: NSLayoutConstraint!
    @IBOutlet var artworkHeight: NSLayoutConstraint!

    var onArtworkTap: (() -> Void)?

    var artwork: UIImage? {
        get {
            return artworkView.image
        }
        set {
            artworkView.image = newValue

            let ratio = artworkView.imageRatio

            artworkHeight.constant = ratio > 1 ? 50.0 / ratio : 50.0
            artworkWidth.constant = ratio < 1 ? 50.0 * ratio : 50.0
        }
    }

    var title: String? {
        get {
            return titleLabel.text
        }
        set {
            titleLabel.text = newValue
        }
    }

    var subtitle: String? {
        get {
            return subtitleLabel.text
        }
        set {
            subtitleLabel.text = newValue
        }
    }

    var progress: Double {
        get {
            return progressView.value
        }
        set {
            progressView.value = newValue.isNaN
                ? 0.0
                : newValue
            setAccessibilityLabels()
        }
    }

    var type: BookCellType = .book {
        didSet {
            switch type {
            case .file:
                accessoryType = .none

                progressTrailing.constant = 11.0
            case .playlist:
                accessoryType = .disclosureIndicator

                progressTrailing.constant = -5.0
            default:
                accessoryType = .none

                progressTrailing.constant = 29.0 // Disclosure indicator offset
            }
        }
    }

    var playbackState: PlaybackState = PlaybackState.stopped {
        didSet {
            UIView.animate(withDuration: 0.1, animations: {
                switch self.playbackState {
                case .playing:
                    self.artworkButton.backgroundColor = UIColor.tintColor.withAlpha(newAlpha: 0.3)
                    self.titleLabel.textColor = UIColor.tintColor
                    self.progressView.pieColor = UIColor.tintColor
                case .paused:
                    self.artworkButton.backgroundColor = UIColor.tintColor.withAlpha(newAlpha: 0.3)
                    self.titleLabel.textColor = UIColor.tintColor
                    self.progressView.pieColor = UIColor.tintColor
                default:
                    self.artworkButton.backgroundColor = UIColor.clear
                    self.titleLabel.textColor = UIColor.textColor
                    self.progressView.pieColor = UIColor(hex: "8F8E94")
                }
            })
        }
    }

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        setup()
    }

    private func setup() {
        accessoryType = .none
        selectionStyle = .none
    }

    override func willMove(toSuperview newSuperview: UIView?) {
        super.willMove(toSuperview: newSuperview)

        artworkButton.layer.cornerRadius = 4.0
        artworkButton.layer.masksToBounds = true
    }

    @IBAction func artworkButtonTapped(_: Any) {
        onArtworkTap?()
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
