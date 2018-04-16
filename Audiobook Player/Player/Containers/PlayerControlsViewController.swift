//
//  PlayerControlsViewController.swift
//  Audiobook Player
//
//  Created by Florian Pichler on 05.04.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

class PlayerControlsViewController: PlayerContainerViewController {
    @IBOutlet private weak var artwork: UIImageView!
    @IBOutlet private weak var playPauseButton: UIButton!
    @IBOutlet private weak var rewindButton: UIButton!
    @IBOutlet private weak var forwardButton: UIButton!

    var book: Book? {
        didSet {
            self.artwork.image = self.book?.artwork
        }
    }

    var isPlaying: Bool = false {
        didSet {
            self.playPauseButton.setImage(self.isPlaying ? self.pauseImage : self.playImage, for: UIControlState())
        }
    }

    let playImage = UIImage(named: "playButton")
    let pauseImage = UIImage(named: "pauseButton")

    override func viewDidLoad() {
        super.viewDidLoad()

        self.isPlaying = PlayerManager.sharedInstance.isPlaying

        self.artwork.layer.shadowColor = UIColor.flatBlack().cgColor
        self.artwork.layer.shadowOffset = CGSize(width: 0, height: 4)
        self.artwork.layer.shadowOpacity = 0.6
        self.artwork.layer.shadowRadius = 6.0
        self.artwork.clipsToBounds = false

        NotificationCenter.default.addObserver(self, selector: #selector(self.onBookPlay), name: Notification.Name.AudiobookPlayer.bookPlayed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onBookPause), name: Notification.Name.AudiobookPlayer.bookPaused, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onBookPause), name: Notification.Name.AudiobookPlayer.bookEnd, object: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // skip time forward
    @IBAction func forward(_ sender: Any) {
        PlayerManager.sharedInstance.forward()
    }

    // skip time backwards
    @IBAction func rewind(_ sender: Any) {
        PlayerManager.sharedInstance.rewind()
    }

    // toggle play/pause of book
    @IBAction func play(_ sender: Any) {
        PlayerManager.sharedInstance.playPause()

        self.isPlaying = PlayerManager.sharedInstance.isPlaying
    }

    @objc func onBookPlay() {
        self.isPlaying = true
    }

    @objc func onBookPause() {
        self.isPlaying = false
    }
}
