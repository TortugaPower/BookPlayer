//
//  PlayerViewController.swift
//  Audiobook Player
//
//  Created by Gianni Carlo on 7/5/16.
//  Copyright © 2016 Tortuga Power. All rights reserved.
//

import UIKit
import AVFoundation
import MediaPlayer
import Chameleon
import StoreKit

class PlayerViewController: UIViewController {
    @IBOutlet weak var authorLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var forwardButton: UIButton!
    @IBOutlet weak var rewindButton: UIButton!
    @IBOutlet weak var maxTimeLabel: UILabel!
    @IBOutlet weak var currentTimeLabel: UILabel!
    @IBOutlet weak var sliderView: UISlider!
    @IBOutlet weak var percentageLabel: UILabel!
    @IBOutlet weak var coverImageView: UIImageView!
    @IBOutlet weak var bottomToolbar: UIToolbar!
    @IBOutlet weak var speedButton: UIBarButtonItem!
    @IBOutlet weak var sleepButton: UIBarButtonItem!
    @IBOutlet weak var spaceBeforeChaptersButton: UIBarButtonItem!
    @IBOutlet weak var chaptersButton: UIBarButtonItem!

    let playImage = UIImage(named: "playButton")
    let pauseImage = UIImage(named: "pauseButton")

    var currentBook: Book!

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Make toolbar transparent
        self.bottomToolbar.setBackgroundImage(UIImage(), forToolbarPosition: .any, barMetrics: .default)
        self.bottomToolbar.setShadowImage(UIImage(), forToolbarPosition: .any)

        NotificationCenter.default.addObserver(self, selector: #selector(self.requestReview), name: Notification.Name.AudiobookPlayer.requestReview, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateTimer(_:)), name: Notification.Name.AudiobookPlayer.updateTimer, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.updatePercentage(_:)), name: Notification.Name.AudiobookPlayer.updatePercentage, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateCurrentChapter(_:)), name: Notification.Name.AudiobookPlayer.updateChapter, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.bookPlayed), name: Notification.Name.AudiobookPlayer.bookPlayed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.bookPaused), name: Notification.Name.AudiobookPlayer.bookPaused, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.bookEnd), name: Notification.Name.AudiobookPlayer.bookEnd, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.bookChange(_:)), name: Notification.Name.AudiobookPlayer.bookChange, object: nil)

        setupView(book: currentBook!)
        playPlayer()
    }

    func setupView(book currentBook: Book) {
        let averageArtworkColor = UIColor(averageColorFrom: currentBook.artwork) ?? UIColor.flatSkyBlueColorDark()

        // Set UI colors
        let artworkColors: [UIColor] = [
            averageArtworkColor!,
            UIColor.flatBlack()
        ]

        self.view.backgroundColor = GradientColor(.topToBottom, frame: view.frame, colors: artworkColors)

        self.maxTimeLabel.textColor = UIColor.flatWhiteColorDark()
        self.titleLabel.textColor = UIColor(contrastingBlackOrWhiteColorOn: averageArtworkColor!, isFlat: true)
        self.authorLabel.textColor = UIColor(contrastingBlackOrWhiteColorOn: averageArtworkColor!, isFlat: true)

        self.coverImageView.image = currentBook.artwork

        // Drop shadow on cover view
        coverImageView.layer.shadowColor = UIColor.flatBlack().cgColor
        coverImageView.layer.shadowOffset = CGSize(width: 0, height: 4)
        coverImageView.layer.shadowOpacity = 0.6
        coverImageView.layer.shadowRadius = 6.0
        coverImageView.clipsToBounds = false

        // Set initial state for slider
        self.sliderView.tintColor = UIColor.flatLimeColorDark()
        self.sliderView.maximumValue = 100
        self.sliderView.value = 0

        self.titleLabel.text = currentBook.title
        self.authorLabel.text = currentBook.author

        // Set percentage label to stored value
        let currentPercentage = UserDefaults.standard.string(forKey: currentBook.identifier+"_percentage") ?? "0%"
        self.percentageLabel.text = currentPercentage

        // Get stored value for current time of book
        let currentTime = UserDefaults.standard.integer(forKey: currentBook.identifier)

        // Update UI if needed and set player to stored time
        if currentTime > 0 {
            let formattedCurrentTime = self.formatTime(currentTime)

            self.currentTimeLabel.text = formattedCurrentTime
        }

        // Update max duration label of book
        let maxDuration = currentBook.duration

        self.maxTimeLabel.text = self.formatTime(maxDuration)

        // Set status bar
        modalPresentationCapturesStatusBarAppearance = true

        self.setStatusBarStyle(UIStatusBarStyleContrast)
    }

    func playPlayer() {
        //get stored value for current time of book
        let currentTime = UserDefaults.standard.integer(forKey: currentBook.identifier)

        if PlayerManager.shared.isPlaying {
            self.playButton.setImage(self.pauseImage, for: UIControlState())
        } else {
            self.playButton.setImage(self.playImage, for: UIControlState())
        }

        if !PlayerManager.shared.chapterArray.isEmpty {
            self.percentageLabel.text = ""
        }

        self.speedButton.title = PlaybackSpeed.shared.format(PlayerManager.shared.currentSpeed)

        self.chaptersButton.isEnabled = !PlayerManager.shared.chapterArray.isEmpty
        self.spaceBeforeChaptersButton.isEnabled = !PlayerManager.shared.chapterArray.isEmpty

        if let audioPlayer = PlayerManager.shared.audioPlayer {
            let percentage = (Float(currentTime) / Float(audioPlayer.duration)) * 100

            self.sliderView.value = percentage
        }
    }

    // MARK: Interface actions

    // skip time forward
    @IBAction func forward(_ sender: UIButton) {
        PlayerManager.shared.forward()
    }

    // skip time backwards
    @IBAction func rewind(_ sender: UIButton) {
        PlayerManager.shared.rewind()
    }

    // toggle play/pause of book
    @IBAction func play(_ sender: UIButton) {
        PlayerManager.shared.playPause()
    }

    @IBAction func sliderValueChanged(_ sender: UISlider) {
        guard let audioPlayer = PlayerManager.shared.audioPlayer else {
            return
        }

        audioPlayer.currentTime = TimeInterval(sender.value / sender.maximumValue) * audioPlayer.duration
    }

    // MARK: Toolbar actions

    @IBAction func setSpeed() {
        let actions = PlaybackSpeed.shared.actionSheet(
            onSelect: { (speed) -> Void in
                PlayerManager.shared.setSpeed(speed)

                self.speedButton.title = PlaybackSpeed.shared.format(PlayerManager.shared.currentSpeed)
            },
            currentSpeed: PlayerManager.shared.currentSpeed
        )

        self.present(actions, animated: true, completion: nil)
    }

    @IBAction func setSleepTimer() {
        let actions = SleepTimer.shared.actionSheet(
            onStart: {},
            onProgress: { (_: Double) -> Void in
//                self.sleepButton.title = SleepTimer.shared.durationFormatter.string(from: timeLeft)
            },
            onEnd: { (_ cancelled: Bool) -> Void in
                if !cancelled {
                    PlayerManager.shared.stop()

                    self.playButton.setImage(self.playImage, for: UIControlState())
                }

//                self.sleepButton.title = "Timer"
            }
        )

        self.present(actions, animated: true, completion: nil)
    }

    // @TODO: Remove from toolbar
    @IBAction func dismissPlayer() {
        self.dismiss(animated: true, completion: nil)
    }

    @IBAction func showMore() {
        let actions = MoreOptions.shared.actionSheet(actions: [
            UIAlertAction(title: "Jump To Start", style: .destructive, handler: { _ in
                self.jump(0.0)
            }),
            UIAlertAction(title: "Mark as Finished", style: .destructive, handler: { _ in
                self.jump(PlayerManager.shared.audioPlayer?.duration ?? 0.0)
                self.bookEnd()
            })
        ])

        self.present(actions, animated: true, completion: nil)
    }

    func jump(_ position: Double = 0.0) {
        guard PlayerManager.shared.isLoaded else {
            return
        }

        PlayerManager.shared.stop()
        PlayerManager.shared.setTime(position)

        let test = Notification(name: Notification.Name.AudiobookPlayer.openURL)

        self.updateTimer(test)
    }

    // MARK: Handle segues from child ViewControllers

    @IBAction func didSelectChapter(_ segue: UIStoryboardSegue) {
        guard PlayerManager.shared.isLoaded else {
            return
        }

        if let viewController = segue.source as? ChaptersViewController {
            let chapter = viewController.currentChapter!

            PlayerManager.shared.setChapter(chapter)
        }
    }

    // MARK: Handle notifications

    @objc func requestReview() {
        // don't do anything if flag isn't true
        guard UserDefaults.standard.bool(forKey: "ask_review") else {
            return
        }

        // request for review
        if #available(iOS 10.3, *), UIApplication.shared.applicationState == .active {
            #if RELEASE
            SKStoreReviewController.requestReview()
            #endif

            UserDefaults.standard.set(false, forKey: "ask_review")
        }
    }

    @objc func bookChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let books = userInfo["books"] as? [Book],
            let book = books.first else {
                return
        }

        self.currentBook = book

        setupView(book: book)
    }

    @objc func updateCurrentChapter(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let fileURL = userInfo["fileURL"] as? URL,
            let chapterString = userInfo["chapterString"] as? String,
            fileURL == self.currentBook.fileURL else {
                return
        }

        self.percentageLabel.text = chapterString
    }

    // timer callback (called every second)
    @objc func updateTimer(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let fileURL = userInfo["fileURL"] as? URL,
            let time = userInfo["time"] as? Int,
            let percentage = userInfo["percentage"] as? Float,
            fileURL == self.currentBook.fileURL else {
            return
        }

        // update current time label
        self.currentTimeLabel.text = self.formatTime(time)

        // update book read percentage
        self.sliderView.value = percentage
    }

    // percentage callback
    @objc func updatePercentage(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let fileURL = userInfo["fileURL"] as? URL,
            fileURL == self.currentBook.fileURL,
            let percentageString = userInfo["percentageString"] as? String,
            let hasChapters = userInfo["hasChapters"] as? Bool,
            !hasChapters else {
                return
        }

        self.percentageLabel.text = percentageString
    }

    @objc func bookPlayed() {
        self.playButton.setImage(self.pauseImage, for: UIControlState())
    }

    @objc func bookPaused() {
        self.playButton.setImage(self.playImage, for: UIControlState())
    }

    @objc func bookEnd() {
        self.playButton.setImage(self.playImage, for: UIControlState())

        self.requestReview()
    }
}
