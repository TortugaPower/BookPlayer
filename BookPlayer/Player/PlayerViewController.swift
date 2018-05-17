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
    var expectedStatusBarStyle: UIStatusBarStyle = .default

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

        if let navigationController = segue.destination as? UINavigationController,
            let viewController = navigationController.viewControllers.first as? ChaptersViewController,
            let currentChapter = self.currentBook.currentChapter {

            viewController.chapters = self.currentBook.chapters?.array as? [Chapter]
            viewController.currentChapter = currentChapter
            viewController.didSelectChapter = { selectedChapter in
                // Don't set the chapter, set the new time which will set the chapter in didSet
                PlayerManager.shared.jumpTo(selectedChapter.start)
            }
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

        // Gestures
        self.pan = UIPanGestureRecognizer(target: self, action: #selector(panAction))
        self.pan.delegate = self
        self.pan.maximumNumberOfTouches = 1
        self.pan.cancelsTouchesInView = true

        self.view.addGestureRecognizer(self.pan)

        self.modalPresentationCapturesStatusBarAppearance = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.controlsViewController?.showPlayPauseButton(animated)
    }

    func setupView(book currentBook: Book) {
        self.metaViewController?.book = currentBook
        self.controlsViewController?.book = currentBook
        self.progressViewController?.book = currentBook

        self.speedButton.title = self.formatSpeed(PlayerManager.shared.speed)

        self.view.backgroundColor = currentBook.artworkColors.background
        self.bottomToolbar.tintColor = currentBook.artworkColors.tertiary
        self.closeButton.tintColor = currentBook.artworkColors.tertiary

        let blur = UIBlurEffect(style: currentBook.artworkColors.displayOnDark ? UIBlurEffectStyle.dark : UIBlurEffectStyle.light)
        let blurView = UIVisualEffectView(effect: blur)

        blurView.frame = backgroundImage.bounds

        self.backgroundImage.addSubview(blurView)
        self.backgroundImage.alpha = 0.2
//        self.backgroundImage.image = currentBook.artworkImage

        self.expectedStatusBarStyle = currentBook.artworkColors.displayOnDark ? UIStatusBarStyle.lightContent : UIStatusBarStyle.default
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return self.expectedStatusBarStyle
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
            if speed == PlayerManager.shared.speed {
                actionSheet.addAction(UIAlertAction(title: "\u{00A0} \(speed) ✓", style: .default, handler: nil))
            } else {
                actionSheet.addAction(UIAlertAction(title: "\(speed)", style: .default, handler: { _ in
                    PlayerManager.shared.speed = speed

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
                    PlayerManager.shared.stop()
                }

                self.sleepLabel.title = ""
            }
        )

        self.present(actionSheet, animated: true, completion: nil)
    }

    @IBAction func showMore() {
        guard PlayerManager.shared.isLoaded else {
            return
        }

        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        actionSheet.addAction(UIAlertAction(title: "Jump To Start", style: .default, handler: { _ in
            PlayerManager.shared.stop()
            PlayerManager.shared.jumpTo(0.0)
        }))

        actionSheet.addAction(UIAlertAction(title: "Mark as Finished", style: .default, handler: { _ in
            PlayerManager.shared.stop()
            PlayerManager.shared.jumpTo(0.0, fromEnd: true)

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

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == self.pan {
            return limitPanAngle(self.pan, degreesOfFreedom: 45.0, comparator: .greaterThan)
        }

        return true
    }

    private func updatePresentedViewForTranslation(_ yTranslation: CGFloat) {
        let translation: CGFloat = rubberBandDistance(yTranslation, dimension: self.view.frame.height, constant: 0.55)

        self.view?.transform = CGAffineTransform(translationX: 0, y: max(translation, 0.0))
    }

    @objc private func panAction(gestureRecognizer: UIPanGestureRecognizer) {
        guard gestureRecognizer.isEqual(self.pan) else {
            return
        }

        switch gestureRecognizer.state {
            case .began:
                gestureRecognizer.setTranslation(CGPoint(x: 0, y: 0), in: self.view.superview)

            case .changed:
                let translation = gestureRecognizer.translation(in: self.view)

                self.updatePresentedViewForTranslation(translation.y)

            case .ended, .cancelled, .failed:
                let dismissThreshold: CGFloat = 44.0 * UIScreen.main.nativeScale
                let translation = gestureRecognizer.translation(in: self.view)

                if translation.y > dismissThreshold {
                    self.dismiss(animated: true, completion: nil)

                    return
                }

                UIView.animate(
                    withDuration: 0.3,
                    delay: 0.0,
                    usingSpringWithDamping: 0.75,
                    initialSpringVelocity: 1.5,
                    options: .preferredFramesPerSecond60,
                    animations: {
                        self.view?.transform = .identity
                    }
                )

            default: break
        }
    }
}
