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

    @IBOutlet weak var timeSeparator: UILabel!

    @IBOutlet weak var sliderView: UISlider!

    @IBOutlet weak var percentageLabel: UILabel!

    @IBOutlet weak var bottomToolbar: UIToolbar!

    @IBOutlet weak var optionsIndicatorButton: UIBarButtonItem!
    @IBOutlet weak var closeButton: UIBarButtonItem!
    @IBOutlet weak var chaptersButton: UIBarButtonItem!
    @IBOutlet weak var speedButton: UIBarButtonItem!
    @IBOutlet weak var sleepButton: UIBarButtonItem!

    @IBOutlet weak var coverImageView: UIImageView!

    //keep in memory images to toggle play/pause
    let playImage = UIImage(named: "playButton")
    let pauseImage = UIImage(named: "pauseButton")

    var currentBook: Book!

    //timer to update sleep time
    var sleepTimer: Timer!

    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Make toolbar transparent
        self.bottomToolbar.setBackgroundImage(UIImage(), forToolbarPosition: .any, barMetrics: .default)
        self.bottomToolbar.setShadowImage(UIImage(), forToolbarPosition: .any)

        registerObservers()
        setupView(book: currentBook!)
        playPlayer()
    }

    func setupView(book currentBook: Book) {
        let averageArtworkColor = UIColor(averageColorFrom: currentBook.artwork) ?? UIColor.flatSkyBlueColorDark()

        //set UI colors
        let artworkColors: [UIColor] = [
            averageArtworkColor!,
            UIColor.flatBlack()
        ]

        self.view.backgroundColor = GradientColor(.topToBottom, frame: view.frame, colors: artworkColors)

        self.maxTimeLabel.textColor = UIColor.flatWhiteColorDark()
        self.titleLabel.textColor = UIColor(contrastingBlackOrWhiteColorOn: averageArtworkColor!, isFlat: true)
        self.authorLabel.textColor = UIColor(contrastingBlackOrWhiteColorOn: averageArtworkColor!, isFlat: true)
        self.timeSeparator.textColor = UIColor.flatWhiteColorDark()

        self.coverImageView.image = currentBook.artwork

        //Drop shadow on cover view
        coverImageView.layer.shadowColor = UIColor.flatBlack().cgColor
        coverImageView.layer.shadowOffset = CGSize(width: 0, height: 4)
        coverImageView.layer.shadowOpacity = 0.6
        coverImageView.layer.shadowRadius = 6.0
        coverImageView.clipsToBounds = false

        //set initial state for slider
        self.sliderView.addTarget(self, action: #selector(sliderChanged(_:)), for: .valueChanged)
        self.sliderView.tintColor = UIColor.flatLimeColorDark()
        self.sliderView.maximumValue = 100
        self.sliderView.value = 0

        self.titleLabel.text = currentBook.title
        self.authorLabel.text = currentBook.author

        //set percentage label to stored value
        let currentPercentage = UserDefaults.standard.string(forKey: currentBook.identifier+"_percentage") ?? "0%"
        self.percentageLabel.text = currentPercentage

        //get stored value for current time of book
        let currentTime = UserDefaults.standard.integer(forKey: currentBook.identifier)

        //update UI if needed and set player to stored time
        if currentTime > 0 {
            let formattedCurrentTime = self.formatTime(currentTime)

            self.currentTimeLabel.text = formattedCurrentTime
        }

        //update max duration label of book
        let maxDuration = currentBook.duration

        self.maxTimeLabel.text = self.formatTime(maxDuration)

        // Set status bar
        modalPresentationCapturesStatusBarAppearance = true

        self.setStatusBarStyle(UIStatusBarStyleContrast)
    }

    func playPlayer() {
        //get stored value for current time of book
        let currentTime = UserDefaults.standard.integer(forKey: currentBook.identifier)

        if PlayerManager.sharedInstance.isPlaying() {
            self.playButton.setImage(self.pauseImage, for: UIControlState())
        } else {
            self.playButton.setImage(self.playImage, for: UIControlState())
        }

        if !PlayerManager.sharedInstance.chapterArray.isEmpty {
            self.percentageLabel.text = ""
        }

        self.speedButton.title = "\(String(PlayerManager.sharedInstance.currentSpeed))x"

        self.chaptersButton.isEnabled = !PlayerManager.sharedInstance.chapterArray.isEmpty

        if let audioPlayer = PlayerManager.sharedInstance.audioPlayer {
            let percentage = (Float(currentTime) / Float(audioPlayer.duration)) * 100

            self.sliderView.value = percentage
        }
    }

    func registerObservers() {
        //register for appDelegate requestReview notifications
        NotificationCenter.default.addObserver(self, selector: #selector(self.requestReview), name: Notification.Name.AudiobookPlayer.requestReview, object: nil)

        //register for timer update
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateTimer(_:)), name: Notification.Name.AudiobookPlayer.updateTimer, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.updatePercentage(_:)), name: Notification.Name.AudiobookPlayer.updatePercentage, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateCurrentChapter(_:)), name: Notification.Name.AudiobookPlayer.updateChapter, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.bookPlayed), name: Notification.Name.AudiobookPlayer.bookPlayed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.bookPaused), name: Notification.Name.AudiobookPlayer.bookPaused, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.bookEnd), name: Notification.Name.AudiobookPlayer.bookEnd, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.bookChange(_:)), name: Notification.Name.AudiobookPlayer.bookChange, object: nil)
    }

    @objc func sliderChanged(_ sender: UISlider) {
        let percentage = sender.value / sender.maximumValue

        if let audioPlayer = PlayerManager.sharedInstance.audioPlayer {
            audioPlayer.currentTime = TimeInterval(percentage) * audioPlayer.duration
        }
    }

    @IBAction func didSelectChapter(_ segue: UIStoryboardSegue) {
        guard PlayerManager.sharedInstance.isLoaded(),
            let viewController = segue.source as? ChaptersViewController,
            let chapter = viewController.currentChapter else {
            return
        }

        PlayerManager.sharedInstance.setChapter(chapter)
    }

    @IBAction func didSelectSpeed(_ segue: UIStoryboardSegue) {
        guard PlayerManager.sharedInstance.isLoaded(),
            let viewController = segue.source as? SpeedViewController,
            let speed = viewController.currentSpeed else {
            return
        }

        PlayerManager.sharedInstance.setSpeed(speed)

        self.speedButton.title = "\(String(PlayerManager.sharedInstance.currentSpeed))x"
    }

    @IBAction func didSelectAction(_ segue: UIStoryboardSegue) {
        guard PlayerManager.sharedInstance.isLoaded() else {
            return
        }

        PlayerManager.sharedInstance.stop()

        if let viewController = segue.source as? MoreViewController {
            guard let action = viewController.selectedAction else {
                return
            }

            switch action.rawValue {
            case MoreAction.jumpToStart.rawValue:
                PlayerManager.sharedInstance.setTime(0.0)
            case MoreAction.markFinished.rawValue:
                PlayerManager.sharedInstance.setTime(PlayerManager.sharedInstance.audioPlayer?.duration ?? 0.0)
            default:
                break
            }

            let test = Notification(name: Notification.Name.AudiobookPlayer.openURL)

            self.updateTimer(test)
        }
    }

    @IBAction func dismissPlayer() {
        self.dismiss(animated: true, completion: nil)
    }

    @IBAction func setSleepTimer(_ sender: UIButton) {
        var alertTitle: String?

        if self.sleepTimer != nil && self.sleepTimer.isValid {
            alertTitle = " "
        }

        let alert = UIAlertController(title: alertTitle, message: nil, preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "Off", style: .default, handler: { _ in
            self.sleep(in: nil)
        }))

        alert.addAction(UIAlertAction(title: "In 5 Minutes", style: .default, handler: { _ in
            self.sleep(in: 300)
        }))

        alert.addAction(UIAlertAction(title: "In 10 Minutes", style: .default, handler: { _ in
            self.sleep(in: 600)
        }))

        alert.addAction(UIAlertAction(title: "In 15 Minutes", style: .default, handler: { _ in
            self.sleep(in: 900)
        }))

        alert.addAction(UIAlertAction(title: "In 30 Minutes", style: .default, handler: { _ in
            self.sleep(in: 1800)
        }))

        alert.addAction(UIAlertAction(title: "In 45 Minutes", style: .default, handler: { _ in
            self.sleep(in: 2700)
        }))

        alert.addAction(UIAlertAction(title: "In One Hour", style: .default, handler: { _ in
            self.sleep(in: 3600)
        }))

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        alert.popoverPresentationController?.sourceView = self.view
        alert.popoverPresentationController?.sourceRect = CGRect(x: Double(self.view.bounds.size.width / 2.0), y: Double(self.view.bounds.size.height-45), width: 1.0, height: 1.0)

        self.present(alert, animated: true, completion: nil)
    }

    func sleep(in seconds: Int?) {
        UserDefaults.standard.set(seconds, forKey: "sleep_timer")

        guard seconds != nil else {
            self.sleepButton.tintColor = UIColor.white
            //kill timer
            if self.sleepTimer != nil {
                self.sleepTimer.invalidate()
            }
            return
        }

        self.sleepButton.tintColor = UIColor.flatLimeColorDark()

        //create timer if needed
        if self.sleepTimer == nil || (self.sleepTimer != nil && !self.sleepTimer.isValid) {
            self.sleepTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateSleepTimer), userInfo: nil, repeats: true)

            RunLoop.main.add(self.sleepTimer, forMode: RunLoopMode.commonModes)
        }
    }

    @objc func updateSleepTimer() {
        guard PlayerManager.sharedInstance.isLoaded() else {
            //kill timer
            if self.sleepTimer != nil {
                self.sleepTimer.invalidate()
            }

            return
        }

        let currentTime = UserDefaults.standard.integer(forKey: "sleep_timer")
        var newTime: Int? = currentTime - 1

        if let alertviewController = self.presentedViewController, alertviewController is UIAlertController {
            alertviewController.title = "Time: " + self.formatTime(newTime!)
        }

        if newTime! <= 0 {
            newTime = nil

            //stop audiobook
            if self.sleepTimer != nil && self.sleepTimer.isValid {
                self.sleepTimer.invalidate()
            }

            if PlayerManager.sharedInstance.isPlaying() {
                self.playPressed(self.playButton)
            }
        }

        UserDefaults.standard.set(newTime, forKey: "sleep_timer")
    }

    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .slide
    }
}

extension PlayerViewController: AVAudioPlayerDelegate {
    //skip time forward
    @IBAction func forwardPressed(_ sender: UIButton) {
        PlayerManager.sharedInstance.forwardPressed()
    }

    //skip time backwards
    @IBAction func rewindPressed(_ sender: UIButton) {
        PlayerManager.sharedInstance.rewindPressed()
    }

    //toggle play/pause of book
    @IBAction func playPressed(_ sender: UIButton) {
        PlayerManager.sharedInstance.playPressed()
    }

    //timer callback (called every second)
    @objc func updateTimer(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let fileURL = userInfo["fileURL"] as? URL,
            let timeText = userInfo["timeString"] as? String,
            let percentage = userInfo["percentage"] as? Float,
            fileURL == self.currentBook.fileURL else {
            return
        }

        //update current time label
        self.currentTimeLabel.text = timeText

        //update book read percentage
        self.sliderView.value = percentage
    }

    //percentage callback
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

    @objc func requestReview() {
        //don't do anything if flag isn't true
        guard UserDefaults.standard.bool(forKey: "ask_review") else {
            return
        }

        // request for review
        if #available(iOS 10.3, *),
            UIApplication.shared.applicationState == .active {
            #if RELEASE
                SKStoreReviewController.requestReview()
            #endif
            UserDefaults.standard.set(false, forKey: "ask_review")
        }
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
}
