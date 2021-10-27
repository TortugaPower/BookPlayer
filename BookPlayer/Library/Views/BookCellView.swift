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

class BookCellView: UITableViewCell {
    @IBOutlet public weak var artworkView: BPArtworkView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var progressView: ItemProgress!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var selectionView: CheckboxSelectionView!
    @IBOutlet private weak var artworkButton: UIButton!
    @IBOutlet weak var artworkWidth: NSLayoutConstraint!
    @IBOutlet weak var artworkHeight: NSLayoutConstraint!
    @IBOutlet weak var customSeparatorView: UIView!

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
            self.progressView.value = newValue.isNaN
                ? 0.0
                : newValue
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
        }
    }

    var type: SimpleItemType = .book {
        didSet {
            switch self.type {
            case .folder:
                self.accessoryType = .disclosureIndicator
            default:
                self.accessoryType = .none
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

  override func setEditing(_ editing: Bool, animated: Bool) {
    super.setEditing(editing, animated: animated)

    self.progressView.isHidden = editing
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
    self.overrideUserInterfaceStyle = theme.useDarkVariant
      ? UIUserInterfaceStyle.dark
      : UIUserInterfaceStyle.light
  }
}
