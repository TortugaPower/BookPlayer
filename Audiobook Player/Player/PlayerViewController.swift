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
    @IBOutlet weak var bottomToolbar: UIToolbar!
    @IBOutlet weak var speedButton: UIBarButtonItem!
    @IBOutlet weak var sleepButton: UIBarButtonItem!
    @IBOutlet weak var spaceBeforeChaptersButton: UIBarButtonItem!
    @IBOutlet weak var chaptersButton: UIBarButtonItem!

    private weak var controlsViewController: PlayerControlsViewController?
    private weak var metaViewController: PlayerMetaViewController?
    private weak var progressViewController: PlayerProgressViewController?


    var currentBook: Book!

    // MARK: Lifecycle

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let viewController = segue.destination as? PlayerControlsViewController {
            controlsViewController = viewController
        }

        if let viewController = segue.destination as? PlayerMetaViewController {
            metaViewController = viewController
        }

        if let viewController = segue.destination as? PlayerProgressViewController {
            progressViewController = viewController
        }

        if segue.identifier == "ChapterSelectionSegue",
            let navigationController = segue.destination as? UINavigationController,
            let viewController = navigationController.viewControllers.first as? ChaptersViewController {
                viewController.book = currentBook
            }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView(book: currentBook!)

        // Make toolbar transparent
        bottomToolbar.setBackgroundImage(UIImage(), forToolbarPosition: .any, barMetrics: .default)
        bottomToolbar.setShadowImage(UIImage(), forToolbarPosition: .any)

        // Observers
        NotificationCenter.default.addObserver(self, selector: #selector(self.requestReview), name: Notification.Name.AudiobookPlayer.requestReview, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.requestReview), name: Notification.Name.AudiobookPlayer.bookEnd, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.bookChange(_:)), name: Notification.Name.AudiobookPlayer.bookChange, object: nil)

        // @TODO: Remove, replace with chapter calculation in book
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateCurrentChapter(_:)), name: Notification.Name.AudiobookPlayer.updateChapter, object: nil)

    }

    func setupView(book currentBook: Book) {
        metaViewController?.book = currentBook
        controlsViewController?.book = currentBook
        progressViewController?.book = currentBook
        progressViewController?.currentTime = UserDefaults.standard.double(forKey: currentBook.identifier)

        speedButton.title = "\(String(PlayerManager.sharedInstance.speed))x"



        setStatusBarStyle(.lightContent)

    }

    // MARK: Interface actions

    @IBAction func dismissPlayer() {
        self.dismiss(animated: true, completion: nil)
    }

    // MARK: Toolbar actions

    @IBAction func setSpeed() {
        let actionSheet = UIAlertController(title: nil, message: "Set playback speed", preferredStyle: .actionSheet)
        let speedOptions: [Float] = [2.5, 2.0, 1.5, 1.25, 1.0, 0.75]

        for speed in speedOptions {
            if speed == PlayerManager.sharedInstance.speed {
                actionSheet.addAction(UIAlertAction(title: "\u{00A0} \(speed) ✓", style: .default, handler: nil))
            } else {
                actionSheet.addAction(UIAlertAction(title: "\(speed)", style: .default, handler: { _ in
                    PlayerManager.sharedInstance.speed = speed

                    self.speedButton.title = "\(String(PlayerManager.sharedInstance.speed))x"
                }))
            }
        }

        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        self.present(actionSheet, animated: true, completion: nil)
    }

    @IBAction func setSleepTimer() {
        let actionSheet = SleepTimer.shared.actionSheet(
            onStart: {},
            onProgress: { (_: Double) -> Void in
//                self.sleepButton.title = SleepTimer.shared.durationFormatter.string(from: timeLeft)
            },
            onEnd: { (_ cancelled: Bool) -> Void in
                if !cancelled {
                    PlayerManager.sharedInstance.stop()
                }

//                self.sleepButton.title = "Timer"
            }
        )

        self.present(actionSheet, animated: true, completion: nil)
    }

    @IBAction func didSelectChapter(_ segue: UIStoryboardSegue) {
        guard PlayerManager.sharedInstance.isLoaded,
            let viewController = segue.source as? ChaptersViewController,
            let chapter = viewController.currentChapter else {
                return
        }

        PlayerManager.sharedInstance.setChapter(chapter)
    }

    @IBAction func showMore() {
        guard PlayerManager.sharedInstance.isLoaded else {
            return
        }

        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        actionSheet.addAction(UIAlertAction(title: "Jump To Start", style: .default, handler: { _ in
            PlayerManager.sharedInstance.stop()
            PlayerManager.sharedInstance.jumpTo(0.0)
        }))

        actionSheet.addAction(UIAlertAction(title: "Mark as Finished", style: .default, handler: { _ in
            PlayerManager.sharedInstance.stop()
            PlayerManager.sharedInstance.jumpTo(0.0, fromEnd: true)

            self.requestReview()
        }))

        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        self.present(actionSheet, animated: true, completion: nil)
    }

    // MARK: Other Methods

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

    }
}
