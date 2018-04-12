//
//  PlayerControlsViewController.swift
//  Audiobook Player
//
//  Created by Florian Pichler on 05.04.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

enum PlayState {
    case playing
    case paused
}

class PlayerControlsViewController: PlayerContainerViewController {
    @IBOutlet private weak var coverImage: UIImageView!
    @IBOutlet private weak var playPauseButton: UIButton!
    @IBOutlet private weak var rewindButton: UIButton!
    @IBOutlet private weak var forwardButton: UIButton!

    var cover: UIImage? {
        get {
            return coverImage.image
        }

        set(image) {
            coverImage.image = image
        }
    }

    var playState: PlayState = .paused {
        didSet {
            if playState == .paused {
                playPauseButton.setImage(playImage, for: UIControlState())
            }

            if playState == .playing {
                playPauseButton.setImage(pauseImage, for: UIControlState())
            }
        }
    }

    let playImage = UIImage(named: "playButton")
    let pauseImage = UIImage(named: "pauseButton")

    override func viewDidLoad() {
        super.viewDidLoad()

        coverImage.layer.shadowColor = UIColor.flatBlack().cgColor
        coverImage.layer.shadowOffset = CGSize(width: 0, height: 4)
        coverImage.layer.shadowOpacity = 0.6
        coverImage.layer.shadowRadius = 6.0
        coverImage.clipsToBounds = false

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

        if PlayerManager.sharedInstance.isPlaying {
            self.playState = .playing
        } else {
            self.playState = .paused
        }
    }

    @objc func onBookPlay() {
        self.playState = .playing
    }

    @objc func onBookPause() {
        self.playState = .paused
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
}
