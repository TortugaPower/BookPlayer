//
//  PlayerViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 7/5/16.
//  Copyright © 2016 Tortuga Power. All rights reserved.
//

import UIKit
import AVFoundation
import MediaPlayer
import StoreKit

class PlayerViewController: UIViewController, UIGestureRecognizerDelegate {
    @IBOutlet private weak var closeButton: UIButton!
    @IBOutlet private weak var closeButtonTop: NSLayoutConstraint!
    @IBOutlet private weak var bottomToolbar: UIToolbar!
    @IBOutlet private weak var speedButton: UIBarButtonItem!
    @IBOutlet private weak var sleepButton: UIBarButtonItem!
    @IBOutlet private weak var sleepLabel: UIBarButtonItem!
    @IBOutlet private weak var spaceBeforeChaptersButton: UIBarButtonItem!
    @IBOutlet private weak var chaptersButton: UIBarButtonItem!
    @IBOutlet private weak var backgroundImage: UIImageView!

    var currentBook: Book!
    private let timerIcon: UIImage = UIImage(named: "toolbarIconTimer")!
    private var pan: UIPanGestureRecognizer!

    private weak var controlsViewController: PlayerControlsViewController?
    private weak var metaViewController: PlayerMetaViewController?
    private weak var progressViewController: PlayerProgressViewController?

    let darknessThreshold: CGFloat = 0.2

    // MARK: Lifecycle

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let viewController = segue.destination as? PlayerControlsViewController {
            self.controlsViewController = viewController
        }

        if let viewController = segue.destination as? PlayerMetaViewController {
            self.metaViewController = viewController
        }

        if let viewController = segue.destination as? PlayerProgressViewController {
            self.progressViewController = viewController
        }

        if segue.identifier == "ChapterSelectionSegue",
            let navigationController = segue.destination as? UINavigationController,
            let viewController = navigationController.viewControllers.first as? ChaptersViewController {
                viewController.book = self.currentBook
            }
    }

    // Prevents dragging the view down from changing the safeAreaInsets.top
    // Note: I'm pretty sure there is a better solution for this that I haven't found yet - @pichfl
    override func viewSafeAreaInsetsDidChange() {
        if #available(iOS 11, *) {
            super.viewSafeAreaInsetsDidChange()

            let window = UIApplication.shared.windows[0]
            let insets: UIEdgeInsets = window.safeAreaInsets

            self.closeButtonTop.constant = self.view.safeAreaInsets.top == 0.0 ? insets.top : 0
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.setupView(book: self.currentBook!)

        // Make toolbar transparent
        self.bottomToolbar.setBackgroundImage(UIImage(), forToolbarPosition: .any, barMetrics: .default)
        self.bottomToolbar.setShadowImage(UIImage(), forToolbarPosition: .any)
        self.sleepLabel.title = ""

        // Observers
        NotificationCenter.default.addObserver(self, selector: #selector(self.requestReview), name: Notification.Name.AudiobookPlayer.requestReview, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.requestReview), name: Notification.Name.AudiobookPlayer.bookEnd, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.bookChange(_:)), name: Notification.Name.AudiobookPlayer.bookChange, object: nil)

        // Gesture
        self.pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        self.pan!.delegate = self
        self.pan!.maximumNumberOfTouches = 1
        self.pan!.cancelsTouchesInView = false

        self.view.addGestureRecognizer(pan!)
    }

    override func viewWillAppear(_ animated: Bool) {
        self.controlsViewController?.showPlayPauseButton(animated)
    }

    func setupView(book currentBook: Book) {
        self.metaViewController?.book = currentBook
        self.controlsViewController?.book = currentBook
        self.progressViewController?.book = currentBook
        self.progressViewController?.currentTime = UserDefaults.standard.double(forKey: currentBook.identifier)

        self.speedButton.title = self.formatSpeed(PlayerManager.sharedInstance.speed)

        var colors = ArtworkColors()

        if !currentBook.usesDefaultArtwork {
            colors = ArtworkColors(image: currentBook.artwork, darknessThreshold: self.darknessThreshold)
        }

        self.view.backgroundColor = colors.background
        self.bottomToolbar.tintColor = colors.tertiary
        self.closeButton.tintColor = colors.tertiary

        self.controlsViewController?.colors = colors
        self.metaViewController?.colors = colors
        self.progressViewController?.colors = colors

        let blur = UIBlurEffect(style: colors.isDark ? UIBlurEffectStyle.dark : UIBlurEffectStyle.light)
        let blurView = UIVisualEffectView(effect: blur)

        blurView.frame = backgroundImage.frame

        self.backgroundImage.addSubview(blurView)
        self.backgroundImage.alpha = 0.2
        self.backgroundImage.image = currentBook.artwork

        // UIViewControllerBasedStatusBarAppearance does not seem to work for ViewControllers that are presented with Over Full Screen
        UIApplication.shared.statusBarStyle = colors.isDark ? UIStatusBarStyle.lightContent : UIStatusBarStyle.default
    }

    override func viewWillDisappear(_ animated: Bool) {
        UIApplication.shared.statusBarStyle = UIStatusBarStyle.default
    }

    // MARK: Interface actions

    @IBAction func dismissPlayer() {
        self.dismiss(animated: true, completion: nil)
    }

    // MARK: Toolbar actions

    @IBAction func setSpeed() {
        let actionSheet = UIAlertController(title: nil, message: "Set playback speed", preferredStyle: .actionSheet)
        let speedOptions: [Float] = [2.5, 2, 1.5, 1.25, 1, 0.75]

        for speed in speedOptions {
            if speed == PlayerManager.sharedInstance.speed {
                actionSheet.addAction(UIAlertAction(title: "\u{00A0} \(speed) ✓", style: .default, handler: nil))
            } else {
                actionSheet.addAction(UIAlertAction(title: "\(speed)", style: .default, handler: { _ in
                    PlayerManager.sharedInstance.speed = speed

                    self.speedButton.title = self.formatSpeed(speed)
                }))
            }
        }

        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        self.present(actionSheet, animated: true, completion: nil)
    }

    @IBAction func setSleepTimer() {
        let actionSheet = SleepTimer.shared.actionSheet(
            onStart: { },
            onProgress: { (timeLeft: Double) -> Void in
                self.sleepLabel.title = SleepTimer.shared.durationFormatter.string(from: timeLeft)
            },
            onEnd: { (_ cancelled: Bool) -> Void in
                if !cancelled {
                    PlayerManager.sharedInstance.stop()
                }

                self.sleepLabel.title = ""
            }
        )

        self.present(actionSheet, animated: true, completion: nil)
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

        self.setupView(book: book)
    }

    // MARK: Gesture recognizers

    private func updatePresentedViewForTranslation(_ yTranslation: CGFloat) {
        let translation: CGFloat = rubberBandDistance(yTranslation, dimension: self.view.frame.height, constant: 0.55)
        let dismissThreshold: CGFloat = self.view.frame.height * 1/6

        if translation > dismissThreshold {
            self.dismiss(animated: true, completion: nil)

            return
        }

        self.view?.transform = CGAffineTransform(translationX: 0, y: translation)
    }

    @objc private func handlePan(gestureRecognizer: UIPanGestureRecognizer) {
        guard gestureRecognizer.isEqual(self.pan) else {
            return
        }

        switch gestureRecognizer.state {
            case .began:
                gestureRecognizer.setTranslation(CGPoint(x: 0, y: 0), in: self.view.superview)

            case .changed:
                let translation = gestureRecognizer.translation(in: self.view)

                self.updatePresentedViewForTranslation(translation.y)

            case .ended:
                UIView.animate(
                    withDuration: 0.3,
                    delay: 0.0,
                    usingSpringWithDamping: 0.7,
                    initialSpringVelocity: 1.4,
                    options: .preferredFramesPerSecond60,
                    animations: {
                        self.view?.transform = .identity
                    },
                    completion: nil
                )

            default: break
        }
    }
}
