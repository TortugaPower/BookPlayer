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
import StoreKit
import UIImageColors

class PlayerViewController: UIViewController, UIGestureRecognizerDelegate {
    @IBOutlet private weak var closeButton: UIButton!
    @IBOutlet private weak var closeButtonTop: NSLayoutConstraint!
    @IBOutlet private weak var bottomToolbar: UIToolbar!
    @IBOutlet private weak var speedButton: UIBarButtonItem!
    @IBOutlet private weak var sleepButton: UIBarButtonItem!
    @IBOutlet private weak var spaceBeforeChaptersButton: UIBarButtonItem!
    @IBOutlet private weak var chaptersButton: UIBarButtonItem!
    @IBOutlet private weak var backgroundImage: UIImageView!

    private let timerIcon: UIImage = UIImage(named: "toolbarIconTimer")!

    private var pan: UIPanGestureRecognizer?

    private weak var controlsViewController: PlayerControlsViewController?
    private weak var metaViewController: PlayerMetaViewController?
    private weak var progressViewController: PlayerProgressViewController?

    var currentBook: Book!

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

    func setupView(book currentBook: Book) {
        self.metaViewController?.book = currentBook
        self.controlsViewController?.book = currentBook
        self.progressViewController?.book = currentBook
        self.progressViewController?.currentTime = UserDefaults.standard.double(forKey: currentBook.identifier)

        self.speedButton.title = "\(String(PlayerManager.sharedInstance.speed))×"

        // Colors
        self.backgroundImage.image = currentBook.artwork

        let colors: UIImageColors = currentBook.artwork.getColors(quality: .highest)
        let blur = UIBlurEffect(style: colors.background.luminance > 0.5 ? UIBlurEffectStyle.light : UIBlurEffectStyle.dark)
        let vibrancy = UIVibrancyEffect(blurEffect: blur)
        let blurView = UIVisualEffectView(effect: blur)
        let vibrancyView = UIVisualEffectView(effect: vibrancy)

        blurView.frame = backgroundImage.frame
        vibrancyView.frame = backgroundImage.frame

        self.backgroundImage.addSubview(blurView)
        self.backgroundImage.addSubview(vibrancyView)
        self.backgroundImage.alpha = 0.2 + (1.0 - colors.background.luminance) * 0.3

        self.view.backgroundColor = colors.background ?? view.backgroundColor

        self.closeButton.tintColor = colors.detail
        self.bottomToolbar.tintColor = colors.detail

        self.metaViewController?.colors = colors
        self.controlsViewController?.colors = colors
        self.progressViewController?.colors = colors
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        guard let luminance = self.view.backgroundColor?.luminance else {
            return UIStatusBarStyle.default
        }

        // Try to keep the default as long as possible to match the rest of the UI
        // This should most likely be inverted if we provide a dark UI as well
        return luminance < 0.3 ? UIStatusBarStyle.lightContent : UIStatusBarStyle.default
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

                    self.speedButton.title = "\(String(PlayerManager.sharedInstance.speed))×"
                }))
            }
        }

        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        self.present(actionSheet, animated: true, completion: nil)
    }

    @IBAction func setSleepTimer() {
        let actionSheet = SleepTimer.shared.actionSheet(
            onStart: {
                self.sleepButton.image = nil
        },
            onProgress: { (timeLeft: Double) -> Void in
                self.sleepButton.title = SleepTimer.shared.durationFormatter.string(from: timeLeft)
            },
            onEnd: { (_ cancelled: Bool) -> Void in
                if !cancelled {
                    PlayerManager.sharedInstance.stop()
                }

                self.sleepButton.title = ""
                self.sleepButton.image = timerIcon
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
    // Based on https://github.com/HarshilShah/DeckTransition/blob/master/Source/DeckPresentationController.swift

    private func updatePresentedViewForTranslation(inVerticalDirection translation: CGFloat) {
        let elasticThreshold: CGFloat = 120.0
        let dismissThreshold: CGFloat = 240.0
        let translationFactor: CGFloat = 0.5

        if translation >= 0 {
            let translationForModal: CGFloat = {
                if translation >= elasticThreshold {
                    let frictionLength = translation - elasticThreshold
                    let frictionTranslation = 30 * atan(frictionLength / elasticThreshold) + frictionLength / 10

                    return frictionTranslation + (elasticThreshold * translationFactor)
                } else {
                    return translation * translationFactor
                }
            }()

            self.view?.transform = CGAffineTransform(translationX: 0, y: translationForModal)

            if translation >= dismissThreshold {
                self.dismiss(animated: true, completion: nil)
            }
        }
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

                self.updatePresentedViewForTranslation(inVerticalDirection: translation.y)

            case .ended:
                UIView.animate(
                    withDuration: 0.25,
                    animations: {
                        self.view?.transform = .identity
                    }
                )

            default: break
        }
    }
}
